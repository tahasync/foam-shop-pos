String currencySymbolFromCode(String code) {
  switch (code.toUpperCase()) {
    case 'PKR':
      return 'Rs';
    case 'USD':
      return '\$';
    case 'EUR':
      return '\u20ac';
    case 'GBP':
      return '\u00a3';
    case 'INR':
      return '\u20b9';
    case 'AED':
      return 'AED';
    case 'SAR':
      return 'SR';
    default:
      return code;
  }
}
