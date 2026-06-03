import 'dart:convert';
import 'package:laptop_controller/core/storage/domain/i_storage_service.dart';

// THIS IS A GLOBAL DUMMY DATABASE
class DatabaseStorage implements IStorageService {
  // A generic map
  final Map<String, dynamic> _memoryStorage = {};

  @override
  Future<void> write<T>(String key, T value) async {
    if (value is String || value is int || value is double || value is bool) {
      _memoryStorage[key] = value;
    } else {
      _memoryStorage[key] = jsonEncode(value);
    }
  }

  @override
  Future<T?> read<T>(String key) async {
    final rawData = _memoryStorage[key];
    if (rawData == null) return null;

    if (rawData is T) {
      return rawData;
    }

    if (rawData is String) {
      try {
        final decoded = jsonDecode(rawData);

        if (decoded is List && T.toString().startsWith('List')) {
          return decoded.toList() as T?;
        }

        if (decoded is Map && T.toString().startsWith('Map')) {
          return Map<String, dynamic>.from(decoded) as T?;
        }
        
        return decoded as T?;
      } catch (_) {
        if (rawData is T) return rawData as T;
        return null;
      }
    }

    return null;
  }

  @override
  Future<void> delete(String key) async {
    _memoryStorage.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _memoryStorage.clear();
  }
}