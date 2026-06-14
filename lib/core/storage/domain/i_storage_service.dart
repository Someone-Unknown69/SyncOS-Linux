// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

abstract interface class IStorageService {
  /// Writes any type of data to a key
  Future<void> write<T>(String key, T value);

  /// Reads data and automatically casts it back to the expected type.
  /// Returns null if the key does not exist.
  Future<T?> read<T>(String key);

  /// Deletes a specific key profile completely.
  Future<void> delete(String key);

  /// Wipes all records across the entire storage layer.
  Future<void> clearAll();
}