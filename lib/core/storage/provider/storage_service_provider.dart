import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/core/storage/data/database_storage.dart';
import 'package:laptop_controller/core/storage/data/prefs_storage.dart';
import 'package:laptop_controller/core/storage/data/secure_storage.dart';
import 'package:laptop_controller/core/storage/data/storage_service.dart';
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
final pairedProvider = StreamProvider<bool>((ref) async* {
  final connectionManager = ref.watch(connectionManagerProvider);

  yield connectionManager.status == ConnectionStatus.active;

  await for (final status in connectionManager.connectionStatusStream) {
    yield status == ConnectionStatus.connected;
  }
});