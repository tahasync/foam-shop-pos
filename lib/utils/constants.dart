class AppConstants {
  AppConstants._();

  static const List<String> foundingAccountEmails = [
    'tahanaeem7372@gmail.com',
    'itx.taha.officail@gmail.com',
    'masifsagar786@gmail.com',
  ];

  static const int trialDays = 14;
  static const int subscriptionWarningDays = 5;
  static const String supportWhatsAppNumber = '+92 3177407596';
  static const String supportEmail = 'taha-codes@outlook.com';
}

/// Normalizes the ShopProfile subscription label ("Trial: N days left") to the
/// reference chip wording ("Trial · N days left") while keeping the live day
/// count. Single source for every place the trial pill is shown.
String trialChipLabel(String label) =>
    label.replaceFirst('Trial: ', 'Trial \u00b7 ');
