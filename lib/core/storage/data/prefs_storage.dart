// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:convert';

import 'package:syncos_linux/core/storage/domain/i_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsStorage implements IStorageService{
  final SharedPreferences _prefs;
    PrefsStorage(this._prefs);

  @override
  Future<void> write<T>(String key, T value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else {
      // If it is a structural List or Map, convert it to a JSON string block
      final String jsonString = jsonEncode(value);
      await _prefs.setString(key, jsonString);
    }
  }

  @override
  Future<T?> read<T>(String key) async {
    if (T == String) return _prefs.getString(key) as T?;
    if (T == int) return _prefs.getInt(key) as T?;
    if (T == bool) return _prefs.getBool(key) as T?;
    if (T == double) return _prefs.getDouble(key) as T?;

    final String? rawJsonString = _prefs.getString(key);
    if (rawJsonString == null) return null;

    try {
      final dynamic decoded = jsonDecode(rawJsonString);
      if (decoded is T) {
        return decoded;
      }
      if (T == Map && decoded is Map) {
        return decoded as T;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> delete(String key) => _prefs.remove(key);

  @override
  Future<void> clearAll() => _prefs.clear();
}