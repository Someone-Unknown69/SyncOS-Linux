import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:laptop_controller/socket_server.dart';

class FileTransfer {
  static const int _ephemeralPort = 0;

  Future<void> sendFile() async {
    final filePath = await _pickFile();

    if (filePath == null) {
      debugPrint('[FTP] No file selected. Aborting transfer.');
      return;
    }

    final file = File(filePath);

    if(!await file.exists()) return;

    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();

    // calculate checksum of file
    debugPrint('[FTP] Calculating checksum for $fileName');
    final checksum = await _calculateChecksum(file);

    // starting a side port
    final ftpServer = await ServerSocket.bind(InternetAddress.anyIPv4, _ephemeralPort);
    final port = ftpServer.port;
    debugPrint('[FTP] Side server listening on port $port');

    // send metadata packet
    SocketServer.instance.send('file_transfer', 'recieve', {
      'fileName': fileName,
      'fileSize': fileSize,
      'checksum': checksum,
      'ftpPort' : port,
      'mimeType': 'application/octet-stream', // willl add more compatablity
    });


    // wait for the accepted reply from peer
    try {
      final socket = await ftpServer.first.timeout(const Duration(seconds: 10));
      debugPrint('[FTP] Phone connected to side socket. Starting stream');
      final reader = file.openRead();

      await socket.addStream(reader);
      
      await socket.flush();
      await socket.close();
    } catch (e) {
      debugPrint('[FTP] Error or Timeout waiting for phone: $e');
    } finally {
      await ftpServer.close();
    }
  }

  Future<void> recieveFile (Map<String, dynamic> metadata) async {
    debugPrint("[FTP] Starting file recieve");
    final ftpPort = metadata['ftpPort'];
    final fileName = metadata['fileName'];
    final expectedChecksum = metadata['checksum'];

    final directory = await getExternalStorageDirectory();

    if (directory == null) {
      debugPrint('[FTP] Could not access external storage directory');
      return;
    }

    final savePath = '${directory.path}/$fileName';
    final file = File(savePath);

    final ftpSocket = await Socket.connect(SocketServer.instance.connectedClientIP, ftpPort);

    final sink = file.openWrite();
    await sink.addStream(ftpSocket);
    
    await sink.close();
    await ftpSocket.close();
    
    final actualChecksum = await _calculateChecksum(file);
    if (actualChecksum == expectedChecksum) {
      debugPrint("[FTP] Transfer Successful: Checksum Matches");
    } else {
      debugPrint("[FTP] Transfer Failed: Checksum Mismatch!");
      await file.delete(); // Delete corrupted file
    }
  }

  // SHA-256 checksum
  Future<String> _calculateChecksum(File file) async {
    final stream = file.openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  }

  // select file to transfer
  Future<String?> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false, // Set true to sync multiple files
        type: FileType.any,    // restrict to .mp4, .pdf, etc. if needed
      );

      // Check if the user picked a file or cancelled
      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        debugPrint('[FTP] Selected file: $filePath');
        return filePath;
      } else {
        // user canceled the picker
        debugPrint('[FTP] User canceled the selection.');
        return null;
      }
    } catch (e) {
      debugPrint('[FTP] Error picking file: $e');
      return null;
    }
  }
}
