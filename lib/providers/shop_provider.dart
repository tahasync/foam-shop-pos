import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_profile.dart';
import '../utils/currency.dart';
import 'firebase_providers.dart';

final shopProfileProvider = StreamProvider<ShopProfile?>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.shopProfileStream();
});

final shopProfileFutureProvider = FutureProvider<ShopProfile?>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getShopProfile();
});

final currencySymbolProvider = Provider<String>((ref) {
  final profileAsync = ref.watch(shopProfileProvider);
  final profile = profileAsync.asData?.value;
  return profile != null ? currencySymbolFromCode(profile.currency) : 'Rs';
});
