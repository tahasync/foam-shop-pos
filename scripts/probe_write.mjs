// Reproduces a client write against PRODUCTION and prints the exact error.
//
// WHY THIS EXISTS
// ---------------
// The emulator suite proves rule *semantics* against a synthetic authenticated
// user. It cannot tell you what a real shop's documents actually contain, and
// the real app swallows the failure into a SnackBar that is gone before a
// screenshot can catch it. This signs in as the real user (via a custom token)
// and replays the write, so the server's own message - including the rule line
// it cites - is visible in the terminal.
//
// USAGE
//   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin.json"
//   $env:SHOP_UID = "the-auth-uid"
//   node probe_write.mjs
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

const { initializeApp, deleteApp } = await import('firebase/app');
const { getAuth, signInWithCustomToken } = await import('firebase/auth');

// A custom token lets the Admin SDK mint credentials for the real user, so the
// request is evaluated by Security Rules exactly as the app's request is.
const token = await admin.auth().createCustomToken(uid);

const app = initializeApp({ apiKey: process.env.FIREBASE_API_KEY, projectId: 'foam-shop-register' });
await signInWithCustomToken(getAuth(app), token);

// The REST API is used deliberately. The Node gRPC transport cannot
// authenticate in this environment, and REST returns the server's own error
// text - including the rules line it cites - which is the whole point here.
const idToken = await getAuth(app).currentUser.getIdToken();
const REST = 'https://firestore.googleapis.com/v1/projects/foam-shop-register/databases/(default)/documents';

const call = async (method, path, body) => {
  const res = await fetch(REST + path, {
    method,
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { ok: res.ok, status: res.status, text };
};

const D = (n) => ({ doubleValue: n });
const S = (s) => ({ stringValue: s });

const productId = process.env.PRODUCT_ID;
const purchaseId = 'probe' + Date.now();

const read = await call('GET', `/users/${uid}/products/${productId}`);
if (!read.ok) {
  // PowerShell truncates stderr, so the body is written to a file as well.
  const { writeFileSync } = await import('node:fs');
  writeFileSync('probe_error.json', read.text);
  console.error('READ FAILED', read.status, '- body written to probe_error.json');
  process.exit(1);
}
const cur = JSON.parse(read.text).fields;
const currentStock = Number(cur.current_stock?.doubleValue ?? 0);
const costPrice = Number(cur.cost_price?.doubleValue ?? 0);
const qty = 1;
const totalStock = currentStock + qty;
const weighted = ((currentStock * costPrice) + qty * costPrice) / totalStock;

// A REST PATCH needs the complete post-update document under `fields`, plus an
// `updateMask`. The mask is omitted so every field in `fields` is written,
// which mirrors what the app's `update()`/`set()` calls send.
const productWrite = await call(
  'PATCH',
  `/users/${uid}/products/${productId}?updateMask.fieldPaths=current_stock&updateMask.fieldPaths=cost_price`,
  {
    fields: { current_stock: D(totalStock), cost_price: D(weighted) },
  },
);
console.log('product update ->', productWrite.status);
if (!productWrite.ok) console.log('  ', productWrite.text.slice(0, 900));

const purchaseFields = {
  id: S(purchaseId),
  date: S(new Date().toISOString()),
  supplier_id: S(''),
  product_id: S(productId),
  qty_or_area: D(qty),
  cost_amount: D(qty * costPrice),
  paid: D(qty * costPrice),
  balance: D(0),
};
const mask = Object.keys(purchaseFields)
  .map((f) => `updateMask.fieldPaths=${f}`)
  .join('&');

const purchaseWrite = await call(
  'PATCH',
  `/users/${uid}/purchases/${purchaseId}?${mask}`,
  { fields: purchaseFields },
);
console.log('purchase create ->', purchaseWrite.status);
if (!purchaseWrite.ok) {
  const { writeFileSync } = await import('node:fs');
  writeFileSync('probe_purchase_error.json', purchaseWrite.text);
  console.log('  body written to probe_purchase_error.json');
}

// Bisect: add the rule's two required fields one at a time, on a throwaway
// document, to find which guard rejects the write.
for (const [label, fields] of [
  ['cost_amount only', { cost_amount: D(qty * costPrice) }],
  ['date only', { date: S(new Date().toISOString()) }],
  ['both', { cost_amount: D(qty * costPrice), date: S(new Date().toISOString()) }],
]) {
  const id2 = 'bisect' + Math.random().toString(36).slice(2, 8);
  const m2 = Object.keys(fields).map((f) => `updateMask.fieldPaths=${f}`).join('&');
  const r = await call('PATCH', `/users/${uid}/purchases/${id2}?${m2}`, { fields });
  console.log(`  bisect [${label}] ->`, r.status);
  if (r.ok) await call('DELETE', `/users/${uid}/purchases/${id2}`);
}

// Restore the shop to the state the probe found it in. A 200 on the product
// update means the write really landed, so skipping this would silently inflate
// the shopkeeper's stock on every run.
if (productWrite.ok) {
  await db.doc(`users/${uid}/products/${productId}`).update({
    current_stock: currentStock,
    cost_price: costPrice,
  });
  console.log('restored product to', { currentStock, costPrice });
}
if (purchaseWrite.ok) {
  await db.doc(`users/${uid}/purchases/${purchaseId}`).delete();
}

// Remove any throwaway documents a bisect run left behind.
const stale = await db
  .collection(`users/${uid}/purchases`)
  .where('__name__', '>=', 'bisect')
  .where('__name__', '<=', 'bisectz')
  .get();
for (const d of stale.docs) await d.ref.delete();
if (!stale.empty) console.log('removed bisect docs:', stale.size);

