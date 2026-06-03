import 'dart:async';
import 'dart:convert';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/storage/domain/i_storage_service.dart';
import 'package:laptop_controller/core/storage/domain/models/app_settings.dart';
import 'package:laptop_controller/core/storage/domain/models/storage_keys.dart';

/// ------------------------      StorageService          ----------------------------
/// This class acts as the centralized "Gatekeeper" for all persistent data in the app.
/// It manages the abstraction between physical storage drivers (Secure vs. Preferences) 
/// and the rest of the application.
/// 
/// Keeps sensitive data (tokens) in secure storage and user preferences/configs in 
///   standard storage.
/// 
/// Provides a unified interface so the UI/Business logic never has to deal with raw 
///   String keys or manual JSON encoding.


class StorageService {
  final IStorageService _secure;
  final IStorageService _prefs;
  final IStorageService _database;

  final _pairingStatusController = StreamController<bool>.broadcast();

  StorageService(this._secure, this._prefs, this._database);


  // ------- Connection Config & Authnentication -----
  Stream<bool> get pairingStream => _pairingStatusController.stream;

  Future<void> setPairingToken(String token) => 
      _secure.write(StorageKeys.pairingToken, token);

  Future<void> clearPairingToken() async {
      _secure.delete(StorageKeys.pairingToken);
      _pairingStatusController.add(false);
  }
  
  Future<String?> getPairingToken() => 
      _secure.read(StorageKeys.pairingToken);

  Future<void> setConnectionConfig(ConnectionConfig config) async {
    final Map<String, dynamic> data = config.toJson();
    final String jsonString = jsonEncode(data);
    await _prefs.write(StorageKeys.connectionConfig, jsonString);
  }

  Future<ConnectionConfig?> getConnectionConfig() async {
    final jsonString = await _prefs.read(StorageKeys.connectionConfig);
    if (jsonString == null) return null;
    
    final Map<String, dynamic> json = jsonDecode(jsonString);
    final String type = json['type'] as String;

    if (type == 'tcp') return TcpConfig.fromJson(json);
    // In case of adding Bluetooth/Other types in future (hopefully) , add them here
    return null;
  }

  Future<bool> get isPaired async {
    final token = await _secure.read(StorageKeys.pairingToken);
    return token != null && token.isNotEmpty;
  }


  // ------------------ App Settings ----------------
  Future<void> setAppSettings(AppSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());
    await _prefs.write(StorageKeys.appSettings, jsonString);
  }

  Future<AppSettings?> getAppSettings() async {
    final jsonString = await _prefs.read(StorageKeys.appSettings);
    if (jsonString == null) return null;
    return AppSettings.fromJson(jsonDecode(jsonString));
  }

  // --- UTILITY ---
  Future<void> clearAll() async {
    await _secure.clearAll();
    await _prefs.clearAll();
  }
  
  // ------------------ Database ------------------------
  /// Natively writes any collection layout (Lists, Maps, primitives) to standard data storage.
  Future<void> writeDatabase<T>(String key, T value) async {
    await _database.write<T>(key, value);
  }

  /// Natively reads data layout structures back out of standard data storage.
  Future<T?> readDatabase<T>(String key) async {
    return await _database.read<T>(key);
  }

  /// Removes a targeted global structural data record.
  Future<void> deleteDatabase(String key) async {
    await _database.delete(key);
  }

  Future<void> clearAllDatabase() async {
    await _database.clearAll();
  }

}