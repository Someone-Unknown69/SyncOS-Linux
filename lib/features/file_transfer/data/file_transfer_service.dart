// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/network/domain/i_connection_manager.dart';
import '../../../core/storage/domain/i_file_service.dart';
import '../../../core/network/domain/i_file_transfer_manager.dart';
import '../../../core/notification/domain/i_notification_service.dart';

// The sendFile method initiates a handshake by sending connectioninfo including size and checksum over 
// the command channel before streaming the file body. 
// RecieveFile acts as an entry point for incoming metadata, 
// Verifys the final checksum against the source. 

// there is no response system so the sending notification will be broken (will fix that later)
// TODO : Fix the sending updates via acknowledgement system

class FileTransferService {
  final IConnectionManager _channel;
  final IFileService _fileService;
  final IFileTransferManager _fileTransferManager;
  final INotificationService _notificationService;

  static const int _notifId = 101;

  static const notificationThrottleMs = 500;

  FileTransferService(
    this._channel, 
    this._fileService, 
    this._fileTransferManager, 
    this._notificationService
  );

  Future<void> sendFile() async {
    final filePath = await _fileService.pickFile();
    if (filePath == null) {
      debugPrint('[FTP] File selection cancelled');
      return;
    }
    
    final file = File(filePath);
    if (!await file.exists()) return;

    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    
    debugPrint('[FTP] Calculating checksum for $fileName');
    final checksum = await _fileService.calculateChecksum(file.path);

    final (socketFuture, connectionInfo) = await _fileTransferManager.send();
    debugPrint('[FTP] Side server ready for connection with $connectionInfo');

    _channel.send('file_transfer', 'receive', {
      'fileName': fileName,
      'fileSize': fileSize,
      'checksum': checksum,
      'connectionInfo': connectionInfo,
      'mimeType': 'application/octet-stream',
    });

    try {
      debugPrint('[FTP] Waiting for receiver to connect');
      final socket = await socketFuture.timeout(const Duration(seconds: 5));

      final sink = socket; 

      int sentSize = 0;
      int lastNotificationTime = 0;
      
      // Show starting notification
      _notificationService.showTransferProgress(
        id: _notifId, 
        title: 'File Transfer', 
        body: 'Starting $fileName...',
        progress: 0,
      );

      await for (List<int> chunk in file.openRead()) {
        sink.add(chunk);
        sentSize += chunk.length;
        
        final now = DateTime.now().millisecondsSinceEpoch;

        debugPrint("[FTP] Updated progress : $sentSize / $fileSize");

        if(now - lastNotificationTime >= notificationThrottleMs) {
          final int progress = ((sentSize / fileSize) * 100).round();

          // We gonna call it unawaited so it doesn't add to latency
          _notificationService.showTransferProgress(
            id: _notifId, 
            title: 'File Transfer', 
            body: 'Sending $fileName',
            progress: progress,
          );

          lastNotificationTime = now;
        }
      }

      await sink.close();
      await _notificationService.showNotification(
        id: _notifId, 
        title: 'File Transfer',
        body: '$fileName Successfully Sent'
      );
    } on TimeoutException{
      debugPrint('[FTP] Error: Connection timed out. Receiver did not connect.');
      _handleTransferError('Receiver did not respond in time');
    } on SocketException catch (e) {
      debugPrint('[FTP] Socket error: ${e.message}');
      _handleTransferError('Network connection failed.');
    } catch (e) {
      debugPrint('[FTP] Unexpected error: $e');
      _handleTransferError('An unknown error occurred.');
    }
  }

  void _handleTransferError(String message) {
    _notificationService.showErrorNotification(
      id: _notifId, 
      title: 'Transfer Failed', 
      error: message,
    );
  }

  Future<void> recieveFile (Map<String, dynamic> metadata) async {
    debugPrint("[FTP] Starting file recieve");
    final connectionInfo = metadata['connectionInfo'];
    final fileName = metadata['fileName'];
    final expectedChecksum = metadata['checksum'];
    final fileSize = metadata['fileSize'];

    await _notificationService.showNotification(
      id: _notifId, 
      title: 'File Transfer',
      body: 'Receiving : $fileName',
    );


    final directoryPath = await _fileService.getExternalStoragePath();
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

    final stream = await _fileTransferManager.receive(connectionInfo);
    final sink = file.openWrite();
    int receivedSize = 0;
    int lastNotificationTime = 0;

    await for (List<int> chunk in stream) {
      sink.add(chunk);
      receivedSize += chunk.length;
      final int progress = ((receivedSize / fileSize) * 100).round();
      
      final now = DateTime.now().millisecondsSinceEpoch;

      if(now - lastNotificationTime >= notificationThrottleMs) {
        _notificationService.showTransferProgress(
          id: _notifId, 
          title: 'File Transfer', 
          body: 'Receiving $fileName',
          progress: progress
        );
      }
    }

    await sink.close();
    
    final actualChecksum = await _fileService.calculateChecksum(file.path);
    if (actualChecksum == expectedChecksum) {
      debugPrint("[FTP] Transfer Successful: Checksum Matches");
      await _notificationService.showNotification(
        id: _notifId, 
        title: 'File Transfer',
        body: '$fileName Received Successfully',
      );

    } else {
      debugPrint("[FTP] Transfer Failed: Checksum Mismatch!");
      await file.delete(); // Delete corrupted file
      await _notificationService.showErrorNotification(
        id: _notifId, 
        title: fileName, 
        error: "Checksum Mismatch"
      );
    }
  }

}