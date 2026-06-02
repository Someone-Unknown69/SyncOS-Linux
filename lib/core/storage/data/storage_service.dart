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
/// Converts complex Data Models (AppSettings, ConnectionConfig) into JSON strings 
///   for storage, and parses them back into objects upon retrieval.
/// 
/// Provides a unified interface so the UI/Business logic never has to deal with raw 
///   String keys or manual JSON encoding.


class StorageService {
  final IStorageService _secure;
  final IStorageService _prefs;

  StorageService(this._secure, this._prefs);


  // ------- Connection Config & Authnentication -----
  Future<void> setPairingToken(String token) => 
      _secure.write(StorageKeys.pairingToken, token);
  
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
  

}