abstract class IFileService {
  Future<String?> pickFile();
  Future<String> getExternalStoragePath();
  Future<String> calculateChecksum(String filePath);
  Stream<List<int>> getFileStream(String filePath);
}