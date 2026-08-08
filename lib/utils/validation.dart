class ValidationError implements Exception {
  final String message;
  final String field;
  const ValidationError(this.field, this.message);

  @override
  String toString() => '[$field] $message';
}

class ValidationResult {
  final List<ValidationError> errors;
  const ValidationResult(this.errors);
  bool get isValid => errors.isEmpty;
  String get summary => errors.map((e) => e.message).join('; ');
}

class Validators {
  static String? nonEmpty(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? maxLength(String? value, int max, String field) {
    if (value != null && value.length > max) return '$field exceeds $max characters';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.length < 7 || cleaned.length > 15) return 'Invalid phone number';
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return 'Phone must contain only digits';
    return null;
  }

  static String? positiveNumber(num? value, String field) {
    if (value == null || value < 0) return '$field must be a positive number';
    return null;
  }

  static String? strictlyPositive(num? value, String field) {
    if (value == null || value <= 0) return '$field must be greater than zero';
    return null;
  }

  static String? nonNegative(num? value, String field) {
    if (value == null || value.isNaN || value.isInfinite) return '$field is invalid';
    if (value < 0) return '$field cannot be negative';
    return null;
  }
}