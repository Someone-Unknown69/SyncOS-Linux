import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/core/storage/domain/i_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage implements IStorageService{
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> write<T>(String key, T value) async {
    try {
      String valueToStore;
      if (value is String) {
        valueToStore = value;
      } else if (value is int || value is bool || value is double) {
        valueToStore = value.toString();
      } else {
        valueToStore = jsonEncode(value);
      }
      
      await _storage.write(key: key, value: valueToStore);
    } catch (e) {
      debugPrint("[SecureStorage] FATAL ERROR WRITING key '$key': $e");
    }
  }

  @override
Future<T?> read<T>(String key) async {
  try {
    final String? rawValue = await _storage.read(key: key);
    if (rawValue == null) return null;

    if (T == String) return rawValue as T?;
    if (T == int) return int.tryParse(rawValue) as T?;
    if (T == bool) return (rawValue == 'true') as T?;
    if (T == double) return double.tryParse(rawValue) as T?;

    final trimmed = rawValue.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final decodedData = jsonDecode(rawValue);
      return decodedData as T?;
    }
    
    return rawValue as T?;
  } catch (e, stack) {
    debugPrint("[SecureStorage] ERROR READING key '$key': $e");
    debugPrint("[SecureStorage] Stack trace $stack");
    return null;
  }
}


  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  
  @override
  Future<void> clearAll() => _storage.deleteAll();

}