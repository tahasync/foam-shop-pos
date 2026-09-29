// Read-only inspector: dumps the live state of one shop so a UI test can be
// verified against Firestore itself rather than against a screenshot.
//
// USAGE
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin.json"
//   $env:SHOP_UID = "the-auth-uid"
//   node inspect_shop.mjs
import admin from 'firebase-admin';
import { cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const uid = process.env.SHOP_UID;
if (!credPath || !uid) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS and SHOP_UID.');
  process.exit(1);
}

admin.initializeApp({ credential: cert(credPath) });
const db = getFirestore();

const shop = db.collection('users').doc(uid);
// The shop profile is a document in the `settings` subcollection, NOT a field on
// the parent user document - see FirestoreService._shopProfile.
const profile = await shop.collection('settings').doc('shopProfile').get();
console.log('--- settings/shopProfile ---');
console.log(JSON.stringify(profile.data(), null, 2));

for (const name of ['products', 'purchases', 'sales', 'customers']) {
  const snap = await shop.collection(name).orderBy('__name__').limit(20).get();
  console.log(`--- ${name} (${snap.size}) ---`);
  for (const d of snap.docs) console.log(d.id, JSON.stringify(d.data()));
}
