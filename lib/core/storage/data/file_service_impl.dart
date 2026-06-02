import 'package:laptop_controller/core/storage/domain/i_file_service.dart';

class FileServiceImpl implements IFileService {
  // TODO : Implement all of these
  @override
  Future<String?> pickFile() => 
    throw UnimplementedError('File picking not implemented yet');

  @override
  Future<String> getExternalStoragePath() => 
    throw UnimplementedError('Storage path lookup not implemented yet');

  @override
  Future<String> calculateChecksum(String filePath) => 
    throw UnimplementedError('Checksum logic not implemented yet');

  @override
  Stream<List<int>> getFileStream(String filePath) => 
    throw UnimplementedError('File streaming not implemented yet');
}