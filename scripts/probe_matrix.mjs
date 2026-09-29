// Creates one throwaway document in each subcollection, as the real user, and
// reports which are allowed. This isolates "which rule is denying" from "which
// field value is wrong" - the purchases denial reproduced even with only valid
// cost_amount + date, so the guard being hit is not the one it appears to be.
//
// Every document created here is deleted again at the end.
//
// USAGE
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin.json"
//   $env:SHOP_UID = "the-auth-uid"
//   $env:FIREBASE_API_KEY = "web api key"
//   node probe_matrix.mjs
import admin from 'firebase-admin';
import { cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const uid = process.env.SHOP_UID;
if (!credPath || !uid) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS and SHOP_UID.');
  process.exit(1);
}

const credential = cert(credPath);
admin.initializeApp({ credential });
const db = getFirestore();
const token = await admin.auth().createCustomToken(uid);

const { initializeApp } = await import('firebase/app');
const { getAuth, signInWithCustomToken } = await import('firebase/auth');

const app = initializeApp({
  apiKey: process.env.FIREBASE_API_KEY,
  projectId: process.env.FIREBASE_PROJECT_ID || 'foam-shop-register',
});
await signInWithCustomToken(getAuth(app), token);
const idToken = await getAuth(app).currentUser.getIdToken();
const REST = `https://firestore.googleapis.com/v1/projects/${
  process.env.FIREBASE_PROJECT_ID || 'foam-shop-register'
}/databases/(default)/documents`;

const call = async (method, path, body) => {
  const res = await fetch(REST + path, {
    method,
    headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { ok: res.ok, status: res.status, text: await res.text() };
};

const D = (n) => ({ doubleValue: n });
const S = (s) => ({ stringValue: s });
const TS = (s) => ({ timestampValue: s });

const stamp = Date.now();
const created = [];

  // Every case below writes the FULL app document, so a rejection can only be
  // about the date value. An earlier version of this probe sent just
  // cost_amount + date, which left the merged document without the other
  // required fields and produced a misleading 403.
  // `date` arrives here as a plain string and is wrapped once, so every case
  // sends a proper Firestore Value. Passing an already-wrapped value into S()
  // produces a 400 that looks like a rules rejection but is a malformed request.
  const purchaseFields = (date) => ({
    id: S('m' + stamp), date: S(date), supplier_id: S(''), product_id: S('p1'),
    qty_or_area: D(1), cost_amount: D(19500), paid: D(19500), balance: D(0),
  });

  const CASES = [
    // The exact shape Purchase.toMap() produces.
    ['purchases (app shape)', 'purchases', purchaseFields(new Date().toISOString())],
    // The literal the emulator suite uses. If THIS is allowed and the ISO string
    // above is not, the rule is fine and the app is writing a date it rejects.
    ['purchases (suite literal)', 'purchases', purchaseFields('2026-09-28T10:00:00')],
    ['purchases (no millis)', 'purchases', purchaseFields('2026-09-28T21:34:49')],
    ['purchases (millis+Z)', 'purchases', purchaseFields('2026-09-28T21:34:49.957Z')],
      ['purchases (timestamp)', 'purchases', {
      ...purchaseFields('2026-09-28T21:34:49'), date: TS(new Date().toISOString()),
    }],
  ['expenses', 'expenses', {
    id: S('m' + stamp), date: S('2026-09-28T10:00:00'),
    amount: D(250), category: S('Rent'),
  }],
  ['customers', 'customers', {
    id: S('m' + stamp), name: S('probe'), baqaya: D(0), phone: S(''),
  }],
  ['suppliers', 'suppliers', { id: S('m' + stamp), name: S('probe') }],
  ['cost_price_history', 'cost_price_history', {
    id: S('m' + stamp), old_cost_price: D(300), new_cost_price: D(320),
    date: S('2026-09-28T10:00:00'),
  }],
  // Dart's DateTime.toIso8601String() emits fractional seconds, e.g.
  // "2026-09-28T21:34:49.957". Firestore's matches() is a FULL match, so the
  // trailing ".957" is fatal if the regex is not anchored permissively.
  ['purchases (dart toIso8601String)', 'purchases', {
    id: S('m' + stamp), date: S(new Date().toISOString().replace('Z', '')),
    supplier_id: S(''), product_id: S('p1'), qty_or_area: D(1),
    cost_amount: D(100), paid: D(100), balance: D(0),
  }],
  ['sales (dart toIso8601String)', 'sales', {
    id: S('m' + stamp), date: S(new Date().toISOString().replace('Z', '')),
    transaction_uuid: S('m' + stamp), paid: D(100), is_voided: false,
    is_quote: false, customer_name: S('probe'), customer_id: S(''),
    line_items: [{ product_id: 'p1', qty_or_area: 1, sale_price: 100,
                   cost_price_at_sale: 50, name: 'p', line_discount_amount: 0 }],
  }],
];

for (const [label, coll, fields] of CASES) {
  // The id must be unique per CASE, and short: this is a .doc() reference, not
  // .collection().add(), so Firestore does not auto-generate and the 20
  // character limit applies.
  //
  // A short prefix of the hex is NOT unique - every label here begins with
  // "purchases (", so the first bytes collide and the cases overwrite one
  // another, which shows up as a 403 on every case after the first. The whole
  // label is hashed instead.
  const docId =
    coll === 'settings/shopProfile'
      ? 'shopProfile'
      : 'm' + createHash('sha1').update(label).digest('hex').slice(0, 12);
  const mask = Object.keys(fields).map((f) => `updateMask.fieldPaths=${f}`).join('&');
  const r = await call('PATCH', `/users/${uid}/${coll}/${docId}?${mask}`, { fields });
  console.log(String(r.status).padEnd(4), label);
  if (r.ok) {
    created.push([coll, docId]);
  } else {
    const m = JSON.parse(r.text).error?.message ?? r.text;
    console.log('     ->', m.slice(0, 300));
  }
}

// Clean up. Admin SDK bypasses rules, so this always succeeds.
for (const [coll, docId] of created) {
  await db.doc(`users/${uid}/${coll}/${docId}`).delete();
  console.log('cleaned up', coll, docId);
}
