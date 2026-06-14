// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/storage/data/database_storage.dart';
import 'package:syncos_linux/core/storage/data/prefs_storage.dart';
import 'package:syncos_linux/core/storage/data/secure_storage.dart';
import 'package:syncos_linux/core/storage/data/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider for the underlying SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize SharedPreferences in main.dart!');
});

// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(SecureStorage(), PrefsStorage(prefs), DatabaseStorage());
});

// Expose whether the app is paired (checks secure storage for pairing token)
final pairingStatusProvider = StreamProvider<bool>((ref) async* {
  final storage = ref.watch(storageServiceProvider);
  yield await storage.isPaired;
  yield* storage.pairingStream;
});