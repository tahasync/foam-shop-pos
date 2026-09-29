class AppConstants {
  AppConstants._();

  // The former `foundingAccountEmails` allowlist lived here. It was three
  // personal email addresses baked into every shipped APK, and it was consulted
  // as if it were an access control. It was not: the person holding the phone
  // chooses which account to sign in with, so a list of addresses proves
  // nothing, and it leaks personal data into a public binary for no benefit.
  //
  // Founder and paid entitlement now lives in the shop profile as
  // `founder_exempt` / `subscription_status`, both of which are server-owned -
  // see the `settings` block in firestore.rules - and are granted out of band by
  // scripts/grant_entitlement.mjs.

  static const int trialDays = 14;
  static const String supportWhatsAppNumber = '+92 3177407596';
  static const String supportEmail = 'taha-codes@outlook.com';
}

/// Normalizes the ShopProfile subscription label ("Trial: N days left") to the
/// reference chip wording ("Trial · N days left") while keeping the live day
/// count. Single source for every place the trial pill is shown.
String trialChipLabel(String label) =>
    label.replaceFirst('Trial: ', 'Trial \u00b7 ');
