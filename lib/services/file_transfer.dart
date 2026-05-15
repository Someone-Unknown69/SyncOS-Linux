import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laptop_controller/socket_server.dart';
import '../main.dart';
import 'package:path_provider/path_provider.dart';


// ------------------------------        FTP Implementation Class       -----------------------------------

class FileTransfer {
  static const int _ephemeralPort = 0;

  Future<void> sendFile(String filePath, {void Function(double)? onProgress}) async {
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

    int sentSize = 0;

    // wait for the accepted reply from peer
    try {
      final socket = await ftpServer.first.timeout(const Duration(seconds: 10));
      debugPrint('[FTP] Phone connected to side socket. Starting stream');
      final reader = file.openRead();

      await for (List<int> chunk in reader) {
        socket.add(chunk);
        sentSize += chunk.length;
        if (onProgress != null) onProgress(sentSize / fileSize);
      }

      await socket.addStream(reader);
      await socket.flush();
      await socket.close();
    } catch (e) {
      debugPrint('[FTP] Error or Timeout waiting for phone: $e');
    } finally {
      await ftpServer.close();
    }
  }

  Future<void> recieveFile (Map<String, dynamic> metadata, {void Function(double)? onProgress}) async {
    debugPrint("[FTP] Starting file recieve");
    final ftpPort = metadata['ftpPort'];
    final fileName = metadata['fileName'];
    final expectedChecksum = metadata['checksum'];
    final fileSize = metadata['fileSize'];

    final directory = await getDownloadsDirectory();
    final directoryPath = directory?.path;

    String savePath = '$directoryPath/$fileName';
    File file = File(savePath);

    // handling duplicate files
    if(await file.exists()) {
      final String extension = fileName.contains('.') ? fileName.split('.').last : '';
      final String nameWithoutExtension = fileName.contains('.') 
          ? fileName.substring(0, fileName.lastIndexOf('.')) 
          : fileName;

      int counter = 1;
      while (await file.exists()) {
        // Construct new name: "test (1).file"
        savePath = '$directoryPath/$nameWithoutExtension ($counter).$extension';
        file = File(savePath);
        counter++;
      }
    }

    final ftpSocket = await Socket.connect(SocketServer.instance.connectedClientIP, ftpPort);
    int receivedSize = 0;
    final sink = file.openWrite();

    await for (List<int> chunk in ftpSocket) {
      sink.add(chunk);
      receivedSize += chunk.length;
      if (onProgress != null) onProgress(receivedSize / fileSize);
    }
    
    await sink.flush();
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
  Future<String?> pickFile() async {
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




// ----------------------------       Progress Snackbar     ---------------------------------------

class TransferSnackbar {
  static void show({
    required String label,
    required String fileName,
    required int fileSize,
    required ValueNotifier<double> progressNotifier,
    required Future<void> task,
    VoidCallback? onCancel,
  }) {
    final state = snackbarKey.currentState;
    final context = snackbarKey.currentContext;
    if (state == null || context == null) return;

    final theme = Theme.of(context);
    final String sizeStr = "${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB";

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: EdgeInsets.only(
          bottom: 24,
          left: 20,
          right: MediaQuery.of(context).size.width * 0.60, 
        ),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, child) {
            final bool isInitializing = progress <= 0;
            final bool isComplete = progress >= 1.0;
            final Color accentColor = isComplete ? Colors.greenAccent[400]! : theme.colorScheme.primary;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Status Icon and Label
                  Row(
                    children: [
                      Icon(
                        isComplete ? Icons.check_circle : (isInitializing ? Icons.sync : Icons.upload_file),
                        color: accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isComplete ? "COMPLETED" : (isInitializing ? "INITIALIZING" : label.toUpperCase()),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Main Content: File Name (Highly Visible)
                  Text(
                    fileName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2, // Allow two lines for visibility
                    style: TextStyle(
                      color: theme.colorScheme.onSurface, // Maximum contrast
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isInitializing ? "Calculating..." : sizeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Linear Progress Section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: isInitializing ? null : (isComplete ? 1.0 : progress),
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Progress Percentage and Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isInitializing ? "Preparing..." : "${(progress * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => snackbarKey.currentState?.hideCurrentSnackBar(),
                        child: Text(
                          isComplete ? "DISMISS" : "CANCEL",
                          style: TextStyle(
                            color: isComplete ? Colors.greenAccent : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Completion/Dismissal Logic
    task.then((_) {
      progressNotifier.value = 1.0;
      Future.delayed(const Duration(seconds: 3), () {
        snackbarKey.currentState?.hideCurrentSnackBar();
      });
    }).catchError((e) {
      _showError("Transfer Failed");
    });
  }

  static void _showError(String msg) {
    snackbarKey.currentState?.hideCurrentSnackBar();
    snackbarKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}