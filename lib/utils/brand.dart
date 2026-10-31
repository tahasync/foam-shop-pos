/// Product identity strings. The product is "Foam Shop"; "Digital Register"
/// is the descriptor/plan name and stays where it already appears.
class AppBrand {
  const AppBrand._();

  static const String name = 'Foam Shop';
  static const String descriptor = 'Digital Register';
  static const String tagline = 'Every sale. Every stock. Every khata.';
}

/// The six solid colours shared by the app mark and exported documents.
///
/// Stored as ARGB integers so Flutter, PDF, and spreadsheet renderers can all
/// use the same source values without introducing a new palette.
class BrandPalette {
  const BrandPalette._();

  static const int deepInk = 0xFF0E0D15;
  static const int deepNavy = 0xFF182346;
  static const int slateBlue = 0xFF3D5387;
  static const int periwinkle = 0xFF7C83AD;
  static const int dustyMauve = 0xFFBFA9BA;
  static const int foamWhite = 0xFFF7F4F2;

  // Low-ink status tints, derived only from the brand tokens above.
  static const int paidTint = 0xFFE8EAF1;
  static const int dueTint = 0xFFF0E8ED;
}
