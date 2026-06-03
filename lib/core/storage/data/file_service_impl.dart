import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:laptop_controller/core/storage/domain/i_file_service.dart';

class FileServiceImpl implements IFileService {
  @override
  Future<String?> pickFile() async {
    final result = await FilePicker.pickFiles();
    return result?.files.single.path;
  }

  @override
  Future<String> getExternalStoragePath() async {
    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final directory = await getDownloadsDirectory();
        return directory?.path ?? (await getApplicationDocumentsDirectory()).path;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        return directory.path;
      }
    } catch (e) {
      final directory = await getTemporaryDirectory();
      return directory.path;
    }
  }

  @override
  Future<String> calculateChecksum(String filePath) async {
    final stream = File(filePath).openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  }

  @override
  Stream<List<int>> getFileStream(String filePath) => File(filePath).openRead();
}