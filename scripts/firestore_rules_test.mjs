// Runs the Firestore security-rules regression suite against the real
// Firestore emulator, using the rules file at the repository root.
//
//   cd scripts
//   npm install --legacy-peer-deps
//   firebase emulators:exec --only firestore --project foam-shop-rules-verify \
//     "node firestore_rules_test.mjs"
//
// Why this is a script and not a `flutter test`: the thing under test is
// server-side authorization, which no widget or unit test can exercise. The
// emulator compiles and evaluates the real rules, so a rule that is
// syntactically invalid, that never matches, or that rejects a legitimate app
// write is caught here rather than in production.


import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

// A real Firestore Timestamp, built by hand: the modular SDK does not export
// Timestamp.fromDate in Node, and the compat subpath is not exported either.
// The wire value is what the rule actually sees, which is the point.
const FIRESTORE_TIMESTAMP = {
  seconds: 1789934089,
  nanoseconds: 957000000,
};

const here = dirname(fileURLToPath(import.meta.url));
// RULES_PATH lets a run target a different rules file, which is how the
// pre-fix isDateString regex is proved to fail these tests (see
// make_old_rules.mjs). Unset, it uses the real file.
const RULES_PATH = process.env.RULES_PATH
  ? resolve(here, process.env.RULES_PATH)
  : join(here, '..', 'firestore.rules');
const RULES = readFileSync(RULES_PATH, 'utf8');
if (process.env.RULES_PATH) {
  console.log(`\n>>> USING ALTERNATE RULES: ${RULES_PATH}\n`);
}

const OWNER = 'shop-owner-uid';
const OTHER = 'some-other-uid';

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'foam-shop-rules-verify',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  await env?.cleanup();
});

// Every test must start from an empty database.
//
// Nearly every test in this file reuses the same document ids - 'p1', 's1',
// 'c1' - because each one independently re-creates what it needs via `seed()`.
// That is fine only if the previous test's documents are gone. Without this
// hook they are NOT, and Firestore is perfectly happy to let them interfere:
// `set()` on an existing document is an UPDATE, not a create, so a test that
// meant to exercise the `create` rule silently exercises `update` instead.
//
// That is not hypothetical. Running this suite against an emulator that already
// held data from a previous run reported two failures - 'sale create' and
// 'cost price history create' - that were pure artefacts of leftover state,
// while both writes passed in isolation and against a fresh emulator. A test
// suite whose verdict depends on whether someone remembered to restart the
// emulator is not a test suite, it is a coin flip.
test.beforeEach(async () => {
  await env.clearFirestore();
});

async function asUser(uid) {
  return env.authenticatedContext(uid, { email: `${uid}@example.invalid` }).firestore();
}

async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

// A product document exactly as Product.toMap() writes it.
const productDoc = (over = {}) => ({
  id: 'p1',
  name: 'Test Foam Sheet',
  type: 'Foam',
  size_length: 6,
  size_width: 4,
  thickness: 2,
  density: 20,
  unit_type: 'per_sqft',
  unit_price: 450,
  cost_price: 300,
  current_stock: 100,
  low_stock_threshold: 10,
  is_archived: false,
  ...over,
});

const saleDoc = (over = {}) => ({
  id: 's1',
  date: '2026-09-28T10:00:00',
  customer_id: 'c1',
  customer_name: 'Test Customer',
  line_items: [
    { product_id: 'p1', qty_or_area: 2, sale_price: 450, name: 'Test Foam Sheet' },
  ],
  paid: 900,
  discount_amount: 0,
  delivery_charge: 0,
  cutting_charge: 0,
  is_voided: false,
  transaction_uuid: 'tx-abc-123',
  ...over,
});

// ── 1. The app's real write paths must keep working ────────────────────────

test('product create (addProduct -> set(toMap())) is allowed', async () => {
  const db = await asUser(OWNER);
  await assertSucceeds(db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
});

test('product full update (updateProduct -> update(toMap())) is allowed', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  // Same id, new name and price. The old rules rejected this outright.
  await assertSucceeds(
    db.collection(`users/${OWNER}/products`).doc('p1')
      .update(productDoc({ name: 'Renamed Foam', unit_price: 500 })),
  );
});

test('product archive (partial is_archived) is allowed', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/products`).doc('p1').update({ is_archived: true }),
  );
});

test('stock decrement on sale is allowed (partial current_stock update)', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/products`).doc('p1').update({ current_stock: 98 }),
  );
});

test('restock (current_stock + weighted cost_price) is allowed', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/products`).doc('p1')
      .update({ current_stock: 150, cost_price: 312.5 }),
  );
});

test('sale create is allowed', async () => {
  const db = await asUser(OWNER);
  await assertSucceeds(db.collection(`users/${OWNER}/sales`).doc('s1').set(saleDoc()));
});

test('sale void (partial is_voided + void_reason) is allowed', async () => {
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(saleDoc()));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/sales`).doc('s1')
      .update({ is_voided: true, void_reason: 'Customer changed mind' }),
  );
});

test('a partial customer update that touches only baqaya is allowed', async () => {
  // A sale writes the customer's outstanding balance with
  // `FieldValue.increment(...)`, which arrives at the rules engine as an opaque
  // server sentinel rather than a number. A numeric check on `baqaya` would
  // therefore reject every sale that leaves a customer with a khata. This is
  // the write that makes that constraint dangerous, so it is pinned here.
  //
  // The literal `FieldValue.increment()` call is not used because the
  // @firebase/rules-unit-testing bundle resolves FieldValue to a class shim
  // with no statics, and the point under test is the RULES, not the SDK's
  // transform. The absence of any `baqaya` validation in the ruleset is
  // asserted statically in the next test, which is the part that could
  // regress.
  const db = await asUser(OWNER);
  await seed((raw) => raw.collection(`users/${OWNER}/customers`).doc('c1')
    .set({ name: 'Test Customer', baqaya: 0, phone: '0300-0000000' }));
  // Partial update: `name` is not in the patch at all, so the rule must be
  // validating the MERGED document, not the patch.
  await assertSucceeds(
    db.collection(`users/${OWNER}/customers`).doc('c1').update({ baqaya: 900 }),
  );
});

test('no rule validates baqaya as a number', async () => {
  // Static counterpart to the test above. If someone later adds
  // `isPositiveNumber(request.resource.data.baqaya)` to make the rules look
  // stricter, this fires - and that change would break every unpaid sale.
  const src = readFileSync(join(here, '..', 'firestore.rules'), 'utf8')
    .replaceAll(/\/\/.*$/gm, '');
  const baqayaChecks = src.match(/baqaya[^\n]*(isNumber|isPositive|isStrictly|>\s*0|<\s*0|isBounded)/g);
  if (baqayaChecks) {
    throw new Error(
      'The customers rules now constrain `baqaya` numerically, which breaks the '
      + 'FieldValue.increment write that every unpaid sale performs:\n  '
      + baqayaChecks.join('\n  '),
    );
  }
});

test('zero-cost purchase (gift / free restock) is allowed', async () => {
  // restockTransaction computes qty * unitCost, which is legitimately 0.
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/purchases`).doc('pu1').set({
      id: 'pu1',
      date: '2026-09-28T10:00:00',
      product_id: 'p1',
      qty_or_area: 5,
      cost_amount: 0,
      paid: 0,
      balance: 0,
      supplier_id: '',
    }),
  );
});

// THE TEST THAT WAS MISSING.
//
// Every other date in this file is a hand-written literal like
// '2026-09-28T10:00:00' - no fractional seconds. The real app never writes
// that: Dart's DateTime.toIso8601String() emits
// "2026-09-28T21:34:49.957123" (and a "Z" for UTC values).
//
// Because Firestore's matches() is a full-string match, the old isDateString
// regex rejected every one of those real values. The suite stayed green while
// purchases, expenses, payments, supplier_payments, opening_balances, sales and
// cost_price_history were ALL denied in production. These tests use the shapes
// the app actually emits, so that cannot regress silently again.
test('dates as Dart writes them are accepted by every isDateString rule', async () => {
  const db = await asUser(OWNER);

  // Exactly what DateTime.now().toIso8601String() returns: microseconds, no zone.
  const dartLocal = '2026-09-28T21:34:49.957123';
  // What toUtc().toIso8601String() returns: microseconds plus Z.
  const dartUtc = '2026-09-28T21:34:49.957123Z';
  // Millisecond precision, which is what a Firestore Timestamp serialises to.
  const millis = '2026-09-28T21:34:49.957';
  // A numeric offset, as from DateTime.parse of an offset string.
  const offset = '2026-09-28T21:34:49.957+05:00';
  // And the plain form, which must keep working for older documents.
  const plain = '2026-09-28T10:00:00';

  for (const [label, date] of [
    ['microseconds, local', dartLocal],
    ['microseconds, Z', dartUtc],
    ['milliseconds', millis],
    ['numeric offset', offset],
    ['plain, no fractional', plain],
  ]) {
    await assertSucceeds(
      db.collection(`users/${OWNER}/purchases`).doc('pu-' + label).set({
        id: 'pu-' + label, date, product_id: 'p1', qty_or_area: 1,
        cost_amount: 100, paid: 100, balance: 0, supplier_id: '',
      }),
      `purchase create with ${label} date: ${date}`,
    );

    await assertSucceeds(
      db.collection(`users/${OWNER}/expenses`).doc('ex-' + label).set({
        id: 'ex-' + label, date, amount: 100, category: 'Rent',
      }),
      `expense create with ${label} date: ${date}`,
    );

    await assertSucceeds(
      db.collection(`users/${OWNER}/sales`).doc('sl-' + label)
        .set(saleDoc({ id: 'sl-' + label, date })),
      `sale create with ${label} date: ${date}`,
    );

    await assertSucceeds(
      db.collection(`users/${OWNER}/cost_price_history`).doc('ch-' + label).set({
        id: 'ch-' + label, date, old_cost_price: 300, new_cost_price: 320,
      }),
      `cost price history create with ${label} date: ${date}`,
    );
  }
});

test('a date that is not a date at all is still refused', async () => {
  // The fix loosened the tail of the pattern, not its strictness about the
  // shape. These must keep failing or the guard is worthless.
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/purchases`).doc('bad');

  for (const bad of [
    'not-a-date',
    '',
    '2026-09-28',            // date only, no time
    '28/09/2026 21:34',      // wrong format entirely
    '2026-13-45T99:99:99',   // right shape, impossible values
    'yesterday',
  ]) {
    await assertFails(
      ref.set({ id: 'bad', date: bad, cost_amount: 100, qty_or_area: 1 }),
      `purchase with invalid date "${bad}" must be refused`,
    );
  }

  // A Firestore Timestamp is not a string, so it is refused too - the rule
  // states `val is string` and the models all write ISO strings.
  await assertFails(
    ref.set({
      id: 'bad', cost_amount: 100, qty_or_area: 1,
      date: FIRESTORE_TIMESTAMP,
    }),
    'a Timestamp date must be refused - the models write ISO strings',
  );
});

test('payment, expense, supplier, supplier payment, opening balance allowed', async () => {
  const db = await asUser(OWNER);
  await assertSucceeds(db.collection(`users/${OWNER}/payments`).doc('pay1').set({
    id: 'pay1', date: '2026-09-28T10:00:00', amount_collected: 500, customer_id: 'c1',
  }));
  await assertSucceeds(db.collection(`users/${OWNER}/expenses`).doc('e1').set({
    id: 'e1', date: '2026-09-28T10:00:00', amount: 250, category: 'Rent',
  }));
  await assertSucceeds(db.collection(`users/${OWNER}/suppliers`).doc('sup1')
    .set({ id: 'sup1', name: 'Test Supplier' }));
  await assertSucceeds(db.collection(`users/${OWNER}/supplier_payments`).doc('sp1').set({
    id: 'sp1', date: '2026-09-28T10:00:00', amount_paid: 100, supplier_id: 'sup1',
  }));
  await assertSucceeds(db.collection(`users/${OWNER}/opening_balances`).doc('ob1').set({
    id: 'ob1', date: '2026-09-28T10:00:00', capital_amount: 50000,
  }));
});

test('shop profile create and rename are allowed', async () => {
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/settings`).doc('shopProfile');
  await assertSucceeds(ref.set({ shop_name: 'Test Foam Shop', location: 'Lahore' }));
  await assertSucceeds(ref.update({ shop_name: 'Renamed Foam Shop' }));
});

test('cost price history create is allowed and update is refused', async () => {
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/cost_price_history`).doc('h1');
  await assertSucceeds(ref.set({
    id: 'h1', date: '2026-09-28T10:00:00', old_cost_price: 300, new_cost_price: 320,
  }));
  await assertFails(ref.update({ new_cost_price: 1 }));
});

test('account deletion can still delete every subcollection', async () => {
  // delete_account_sheet.dart batch-deletes these after a re-auth. Denying
  // delete outright would strand a shopkeeper's own data, so it must stay
  // permitted - and the flow voids every sale first precisely because a LIVE
  // sale is no longer deletable (see the two tests below).
  await seed(async (db) => {
    await db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc());
    await db.collection(`users/${OWNER}/sales`).doc('s1').set(
      saleDoc({ is_voided: true }),
    );
  });
  const db = await asUser(OWNER);
  const batch = db.batch();
  batch.delete(db.collection(`users/${OWNER}/products`).doc('p1'));
  batch.delete(db.collection(`users/${OWNER}/sales`).doc('s1'));
  await assertSucceeds(batch.commit());
});

test('a LIVE sale cannot be deleted', async () => {
  // The reason account deletion voids first. A real day's revenue must not be
  // removable in one unaudited step.
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(
    saleDoc({ is_voided: false }),
  ));
  const db = await asUser(OWNER);
  await assertFails(db.collection(`users/${OWNER}/sales`).doc('s1').delete());
});

test('a sale can be voided and then deleted (the audited route)', async () => {
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(
    saleDoc({ is_voided: false }),
  ));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/sales`).doc('s1');
  // Step 1: the cancellation, which the rules permit and which records intent.
  await assertSucceeds(ref.update({ is_voided: true, void_reason: 'Customer cancelled' }));
  // Step 2: removal is allowed only after that.
  await assertSucceeds(ref.delete());
});

test('a voided sale still cannot be un-voided', async () => {
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(
    saleDoc({ is_voided: true }),
  ));
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/sales`).doc('s1').update({ is_voided: false }),
  );
});

test('account deletion voids a live sale before deleting it', async () => {
  // End-to-end shape of the real flow: the two calls delete_account_sheet.dart
  // makes, in the order it makes them. If the rule ever tightens so that the
  // void itself is refused, this fails - which is the point.
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(
    saleDoc({ is_voided: false }),
  ));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/sales`).doc('s1');
  await assertSucceeds(ref.update({ is_voided: true, void_reason: 'Account deleted' }));
  await assertSucceeds(ref.delete());
});

test('re-running account deletion over already-voided sales is idempotent', async () => {
  // The flow skips sales that are already voided so a retry cannot trip the
  // is_voided immutability rule and strand the account half-deleted.
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(
    saleDoc({ is_voided: true }),
  ));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/sales`).doc('s1');
  const isVoided = (await ref.get()).data()['is_voided'] == true;
  if (!isVoided) {
    await assertFails(ref.update({ is_voided: true, void_reason: 'Account deleted' }));
  }
  await assertSucceeds(ref.delete());
});

// ── 2. The guarantees must actually be enforced now ─────────────────────────

test('cross-tenant access is denied in both directions', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OTHER);
  await assertFails(db.collection(`users/${OWNER}/products`).doc('p1').get());
  await assertFails(db.collection(`users/${OWNER}/products`).doc('p1').update({ name: 'Stolen' }));
});

test('signed-out access is denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(db.collection(`users/${OWNER}/products`).doc('p1').get());
  await assertFails(db.collection(`users/${OWNER}/sales`).doc('s1').set(saleDoc()));
});

test('an archived product cannot be un-archived', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1')
    .set(productDoc({ is_archived: true })));
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/products`).doc('p1').update({ is_archived: false }),
  );
});

test('a product id cannot be rewritten', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/products`).doc('p1').update({ id: 'hijacked' }),
  );
});

test('a product cannot be blanked or given negative stock', async () => {
  await seed((db) => db.collection(`users/${OWNER}/products`).doc('p1').set(productDoc()));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/products`).doc('p1');
  await assertFails(ref.update({ name: '' }));
  await assertFails(ref.update({ current_stock: -50 }));
});

test('a voided sale cannot be un-voided', async () => {
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1')
    .set(saleDoc({ is_voided: true })));
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/sales`).doc('s1').update({ is_voided: false }),
  );
});

test('a recorded sale cannot be rewritten after the fact', async () => {
  // This is the guarantee the old rules claimed and never enforced.
  await seed((db) => db.collection(`users/${OWNER}/sales`).doc('s1').set(saleDoc()));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/sales`).doc('s1');
  await assertFails(ref.update({ paid: 1 }));
  await assertFails(ref.update({ date: '2020-01-01T00:00:00' }));
  await assertFails(ref.update({ transaction_uuid: 'different' }));
  await assertFails(ref.update({
    line_items: [{ product_id: 'p1', qty_or_area: 999, sale_price: 1 }],
  }));
});

test('a malformed sale is rejected on create', async () => {
  const db = await asUser(OWNER);
  const col = db.collection(`users/${OWNER}/sales`);
  await assertFails(col.doc('bad1').set(saleDoc({ paid: -100 })));
  await assertFails(col.doc('bad2').set(saleDoc({ line_items: [] })));
  await assertFails(col.doc('bad3').set(saleDoc({ transaction_uuid: '' })));
  await assertFails(col.doc('bad4').set(saleDoc({ date: 'not-a-date' })));
});

test('KNOWN LIMITATION: a bad line item is not caught server-side', async () => {
  // This asserts the CURRENT, imperfect behaviour on purpose. It is written as
  // a positive assertion so that it fails loudly if the situation ever
  // changes in either direction, rather than leaving the gap undocumented.
  //
  // A line item with qty_or_area: 0 is nonsense - `SaleLineItem.fromMap`
  // throws FormatException on exactly this input - but the ruleset cannot
  // reject it. Firestore Security Rules have no iteration construct (List
  // offers only hasAll/hasAny/size/toSet), so there is no way to express
  // "every element of line_items must ...". The original file tried, with
  // `line_items.all(li => ...)`, which does not compile.
  //
  // Closing this properly needs a Cloud Function that validates the document,
  // not a rule. Until then the guard is client-side only.
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/sales`).doc('known-gap-1').set(saleDoc({
      line_items: [{ product_id: 'p1', qty_or_area: 0, sale_price: 450 }],
    })),
  );
});

test('a nameless product or customer is rejected', async () => {
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/products`).doc('p9')
      .set(productDoc({ name: '' })),
  );
  await assertFails(
    db.collection(`users/${OWNER}/customers`).doc('c9').set({ name: '' }),
  );
});

test('an unknown subcollection is denied', async () => {
  // Previously dead: the blanket parent grant let any new collection be written.
  const db = await asUser(OWNER);
  await assertFails(db.collection(`users/${OWNER}/secrets`).doc('s').set({ token: 'x' }));
  await assertFails(db.collection(`users/${OWNER}/anything_at_all`).doc('s').set({ a: 1 }));
});

// ── 3. The paywall must not be forgeable by the client ─────────────────────
//
// `founder_exempt` and `subscription_status` are a payment decision. Before
// these rules, any signed-in user could write `free_forever` into their own
// shop profile and unlock the paid tier, because the only client-side
// protection was a hardcoded list of three email addresses in the APK - which
// a user simply does not have to be.

test('a client cannot grant itself free_forever on create', async () => {
  const db = await asUser(OWNER);
  await assertFails(
    db.collection(`users/${OWNER}/settings`).doc('shopProfile').set({
      shop_name: 'Test Foam Shop',
      location: 'Lahore',
      subscription_status: 'free_forever',
      founder_exempt: true,
    }),
  );
});

test('a client cannot flip itself to free_forever on update', async () => {
  await seed((raw) => raw.collection(`users/${OWNER}/settings`).doc('shopProfile').set({
    shop_name: 'Test Foam Shop',
    location: 'Lahore',
    subscription_status: 'trial',
    founder_exempt: false,
  }));
  const db = await asUser(OWNER);
  const ref = db.collection(`users/${OWNER}/settings`).doc('shopProfile');
  await assertFails(ref.update({ subscription_status: 'free_forever' }));
  await assertFails(ref.update({ founder_exempt: true }));
  // Nor can it forge an expiry, which would read as a paid period.
  await assertFails(ref.update({ subscription_expires_at: '2099-01-01T00:00:00' }));
});

test('an existing entitled shop can still rename itself and move', async () => {
  // The immutability checks must not break a shop that already holds a paid
  // status - the common day-to-day edit has to keep working.
  await seed((raw) => raw.collection(`users/${OWNER}/settings`).doc('shopProfile').set({
    shop_name: 'Test Foam Shop',
    location: 'Lahore',
    subscription_status: 'free_forever',
    founder_exempt: true,
  }));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/settings`).doc('shopProfile')
      .update({ shop_name: 'Renamed Foam Shop', phone: '0300-0000000' }),
  );
});

test('a trial shop can edit contact details without touching entitlement', async () => {
  await seed((raw) => raw.collection(`users/${OWNER}/settings`).doc('shopProfile').set({
    shop_name: 'Test Foam Shop',
    location: 'Lahore',
    subscription_status: 'trial',
    founder_exempt: false,
  }));
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/settings`).doc('shopProfile')
      .update({ location: 'Karachi', currency: 'USD' }),
  );
});

test('a brand new shop still starts on an ordinary trial', async () => {
  // The rule must not brick sign-up: the normal onboarding write still works.
  const db = await asUser(OWNER);
  await assertSucceeds(
    db.collection(`users/${OWNER}/settings`).doc('shopProfile').set({
      shop_name: 'New Shop',
      location: 'Lahore',
      phone: '',
      currency: 'PKR',
      subscription_status: 'trial',
      founder_exempt: false,
    }),
  );
});

test('a document outside the user scope is denied', async () => {
  const db = await asUser(OWNER);
  await assertFails(db.collection('_ids').doc('x').set({ a: 1 }));
  await assertFails(db.collection('users').doc(OWNER).set({ a: 1 }));
});
