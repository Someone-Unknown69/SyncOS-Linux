import 'dart:convert';

import 'package:laptop_controller/core/storage/domain/i_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage implements IStorageService{
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> write<T>(String key, T value) async {
    if (value is String) {
      await _storage.write(key: key, value: value);
    } else if (value is int || value is bool || value is double) {
      await _storage.write(key: key, value: value.toString());
    } else {
      final String jsonString = jsonEncode(value);
      await _storage.write(key: key, value: jsonString);
    }
  }

  @override
  Future<T?> read<T>(String key) async {
    final String? rawValue = await _storage.read(key: key);
    if (rawValue == null) return null;

    if (T == String) {
      return rawValue as T?;
    }

    if (T == int) {
      return int.tryParse(rawValue) as T?;
    }
    if (T == bool) {
      if (rawValue == 'true') return true as T;
      if (rawValue == 'false') return false as T;
      return null;
    }
    if (T == double) {
      return double.tryParse(rawValue) as T?;
    }

    try {
      final decodedData = jsonDecode(rawValue);
      return decodedData as T?;
    } catch (_) {
      return null;
    }
  }


  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  
  @override
  Future<void> clearAll() => _storage.deleteAll();

}