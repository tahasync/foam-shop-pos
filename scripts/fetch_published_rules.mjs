// Fetches the ruleset actually deployed to production and diffs it against the
// local firestore.rules.
//
// WHY THIS EXISTS
// ---------------
// The emulator suite proves the LOCAL file behaves as intended. It says nothing
// about what is live. If the deployed ruleset differs in any way, every
// emulator result is about a ruleset nobody is running, and a write can fail in
// production for reasons the tests could never surface.
//
// USAGE
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin.json"
//   node fetch_published_rules.mjs
import admin from 'firebase-admin';
import { cert } from 'firebase-admin/app';
import { readFileSync, writeFileSync } from 'node:fs';

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const projectId = process.env.FIREBASE_PROJECT_ID || 'foam-shop-register';
if (!credPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS.');
  process.exit(1);
}

const credential = cert(credPath);
admin.initializeApp({ credential, projectId });
const access = await credential.getAccessToken();

const res = await fetch(
  `https://firebaserules.googleapis.com/v1/projects/${projectId}/releases/cloud.firestore`,
  { headers: { Authorization: `Bearer ${access.access_token}` } },
);
const body = await res.json();

if (!res.ok) {
  console.error('fetch failed', res.status, JSON.stringify(body).slice(0, 500));
  process.exit(1);
}

// A release only names a ruleset; the text lives behind the ruleset resource.
const rulesetName = body.rulesetName;
if (!rulesetName) {
  console.error('no rulesetName in release', JSON.stringify(body));
  process.exit(1);
}
const created = body.updateTime ?? body.createTime;
console.log('release points at:', rulesetName, 'updated', created);

const rs = await fetch(
  `https://firebaserules.googleapis.com/v1/${rulesetName}`,
  { headers: { Authorization: `Bearer ${access.access_token}` } },
);
const rulesetBody = await rs.json();
if (!rs.ok) {
  console.error('ruleset fetch failed', rs.status, JSON.stringify(rulesetBody).slice(0, 500));
  process.exit(1);
}

// `source` is a Source object, not a string: { files: [{ name, content }] }.
const source = rulesetBody.source;
const published = Array.isArray(source?.files)
  ? source.files.map((f) => f.content).join('\n')
  : (source?.content ?? rulesetBody.rules ?? JSON.stringify(rulesetBody, null, 2));

if (typeof published !== 'string') {
  console.error('unexpected ruleset shape:', JSON.stringify(rulesetBody).slice(0, 800));
  process.exit(1);
}

writeFileSync('published_rules.rules', published);
console.log('published bytes:', published.length);

const local = readFileSync('../firestore.rules', 'utf8');
console.log('local bytes:    ', local.length);
console.log('IDENTICAL:', published.trim() === local.trim());
if (published.trim() !== local.trim()) {
  console.log('\n--- published differs; first 2000 chars of published ---');
  console.log(published.slice(0, 2000));
}
