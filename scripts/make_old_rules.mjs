// Writes scripts/OLD_firestore.rules: the current rules with the isDateString
// regex reverted to its pre-fix form.
//
// Purpose: prove the new regression tests actually FAIL against the old regex.
// A test that passes both before and after a fix proves nothing, and this one
// was green against a regex that denied every real app write.
//
//   node make_old_rules.mjs
import { readFileSync, writeFileSync } from 'node:fs';

const src = readFileSync('../firestore.rules', 'utf8');

// The pre-fix pattern: prefix-only, and with the `\\d` escaping that matches a
// literal backslash rather than a digit class.
const OLD_PATTERN = "val.matches('^\\\\d{4}-\\\\d{2}-\\\\d{2}T\\\\d{2}:\\\\d{2}:\\\\d{2}');";
const NEW_PATTERN =
  "val.matches('^\\\\d{4}-\\\\d{2}-\\\\d{2}T\\\\d{2}:\\\\d{2}:\\\\d{2}(\\\\.\\\\d+)?(Z|[+-]\\\\d{2}:?\\\\d{2})?$');";

if (!src.includes(NEW_PATTERN)) {
  console.error('could not find the current isDateString pattern; has the fix changed?');
  process.exit(1);
}

const out = src.replace(NEW_PATTERN, OLD_PATTERN);
writeFileSync('OLD_firestore.rules', out);
console.log('wrote OLD_firestore.rules with the pre-fix regex:');
console.log('  ' + OLD_PATTERN);
