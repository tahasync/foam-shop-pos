// Grants a shop its subscription entitlement, server-side.
//
// WHY THIS EXISTS
// ---------------
// `founder_exempt` and `subscription_status` used to be written by the app
// itself, which meant the client decided whether it had paid. The Firestore
// rules now make both fields server-owned: a client write that changes them is
// denied. Only the Admin SDK bypasses Security Rules, so this script is the
// supported way to grant access.
//
// This is the correct shape for a payment decision — the party that pays must
// not be the party that authorises.
//
// USAGE
// -----
//   cd scripts
//   npm install
//
//   # 1. Authenticate. Three options, easiest first.
//
//   #    (a) A service-account key from the Firebase console - no extra tooling.
//   #        Project Settings > Service accounts > Generate new private key.
//   #        Move the downloaded JSON OUTSIDE the repo, then:
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin.json"
//
//   #    (b) gcloud, if installed and already signed in:
//   gcloud auth application-default login
//
//   #    (c) Reuse the Firebase CLI's credentials, if you have run
//   #        `firebase login` (no gcloud needed):
//   $env:GOOGLE_APPLICATION_CREDENTIALS =
//     "$env:APPDATA\firebase\decoder-decoder-*.json"
//
//   # 2. Find the shop owner's Firebase Auth UID (Firebase console > Authentication).
//   $env:SHOP_UID = "the-auth-uid"
//
//   # 3. Grant:
//   node grant_entitlement.mjs free_forever     # founder / lifetime access
//   node grant_entitlement.mjs active 365       # paid, expires in 365 days
//   node grant_entitlement.mjs trial 14         # extend the trial
//   node grant_entitlement.mjs inspect
//
//   ALWAYS run `inspect` afterwards and confirm the fields in the console. This
//   script is the only supported way to change entitlement, and the app reads
//   it on every launch.
//
// A SERVICE-ACCOUNT KEY IS A MASTER KEY. It bypasses Security Rules entirely -
// it is precisely the privilege the rules in this repo exist to withhold from
// clients. Keep it outside the repository, never commit it, and delete it once
// the grants are done. `.gitignore` blocks the console's default download
// filename as a backstop, not as a substitute for care.
//
// NOT VERIFIED HERE
// -----------------
// This script has not been executed in this environment: it needs a Google
// credential and a real shop UID, neither of which is available from a source
// checkout. It is written against the documented Admin SDK surface, but treat
// the first run as untested and check the Firestore document afterwards.

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'foam-shop-register';
const UID = process.env.SHOP_UID;
const MODE = process.argv[2];
const ARG = process.argv[3];

if (!UID) {
  console.error(
    'Set SHOP_UID to the shop owner\'s Firebase Auth UID.\n' +
    'Find it in Firebase console > Authentication > Users.',
  );
  process.exit(1);
}

initializeApp({
  credential: applicationDefault(),
  projectId: PROJECT_ID,
});

const db = getFirestore();
const ref = db.doc(`users/${UID}/settings/shopProfile`);

function iso(daysFromNow) {
  if (daysFromNow == null) return null;
  const d = new Date();
  d.setDate(d.getDate() + Number(daysFromNow));
  return d.toISOString();
}

async function main() {
  if (MODE === 'inspect') {
    const snap = await ref.get();
    if (!snap.exists) {
      console.error(`No shop profile for ${UID}. Has the shop finished onboarding?`);
      process.exit(1);
    }
    console.log(JSON.stringify(snap.data(), null, 2));
    return;
  }

  let update;
  switch (MODE) {
    case 'free_forever':
      // Founder / lifetime grant. trial_ends_at is cleared so nothing later
      // re-evaluates it back down to an expired trial.
      update = {
        subscription_status: 'free_forever',
        founder_exempt: true,
        trial_ends_at: null,
        subscription_expires_at: null,
      };
      break;
    case 'active':
      update = {
        subscription_status: 'active',
        founder_exempt: false,
        subscription_expires_at: iso(ARG ?? 365),
      };
      break;
    case 'trial':
      update = {
        subscription_status: 'trial',
        founder_exempt: false,
        trial_ends_at: iso(ARG ?? 14),
      };
      break;
    default:
      console.error(
        'Usage: node grant_entitlement.mjs <free_forever|active|trial|inspect> [days]',
      );
      process.exit(1);
  }

  await ref.set(update, { merge: true });
  console.log(`Granted "${MODE}" to ${UID}:`);
  console.log(JSON.stringify(update, null, 2));
}

main().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
