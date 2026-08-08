import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
