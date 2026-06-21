import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:http/http.dart' as http;

Future<Uri> base64ToTmpFile(String base64String) async {
  final tmpDir = await getTemporaryDirectory();

  final bytes = base64Decode(base64String);
  final hash = sha256.convert(bytes).toString().substring(0, 16);
  final targetFileName = 'album_art_$hash.jpg';
  final file = File('${tmpDir.path}/$targetFileName');

  // Clears out any PREVIOUS track artwork files from the temp directory
  try {
    final dir = Directory(tmpDir.path);
    if (await dir.exists()) {
      final files = dir.listSync();
      for (var entity in files) {
        if (entity is File &&
            entity.path.contains('album_art_') &&
            !entity.path.endsWith(targetFileName)) {
          await entity.delete();
        }
      }
    }
  } catch (e) {
    logDebug('Image Decode', 'Error cleaning up previous artwork: $e');
  }

  if (!await file.exists()) {
    await file.writeAsBytes(bytes);
  }

  return file.uri;
}

Future<String> fileToBase64(Uri fileUri) async {
  List<int> bytes;

  if (fileUri.scheme == 'file') {
    final file = File.fromUri(fileUri);
    bytes = await file.readAsBytes();
  } else if (fileUri.scheme == 'http' || fileUri.scheme == 'https') {
    final response = await http.get(fileUri);
    if (response.statusCode == 200) {
      bytes = response.bodyBytes;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  } else {
    throw UnsupportedError('Unsupported URI scheme: ${fileUri.scheme}');
  }

  return base64Encode(bytes);
}
