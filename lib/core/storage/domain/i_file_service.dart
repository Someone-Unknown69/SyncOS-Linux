// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

abstract class IFileService {
  Future<String?> pickFile();
  Future<String> getExternalStoragePath();
  Future<String> calculateChecksum(String filePath);
  Stream<List<int>> getFileStream(String filePath);
}