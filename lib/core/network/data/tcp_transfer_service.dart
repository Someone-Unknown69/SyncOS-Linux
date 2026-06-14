// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:io';
import 'dart:async';
import '../domain/i_file_transfer_manager.dart';
import 'package:flutter/foundation.dart';

// In case of changing the file transfer implementation to server based or bluetooth based
// the connection logic shall be added in this file
// This is the file transfer infrastrucre

class TcpTransferTransport implements IFileTransferManager {
  @override
  Future<(Future<Socket>, Map<String, dynamic>)> send() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    
    final localIp = await _getLocalIpAddress();

    // We include the host here so the receiver knows exactly where to look
    final metadata = {
      'port': server.port,
      'host': localIp ?? '127.0.0.1',
    };

    debugPrint('[FTP] Server bound on port ${server.port}. Waiting for connection...');

    final connectionFuture = server.first.then((socket) {
      server.close(); // Clean up the server listener once connected
      return socket;
    });
    
    return (connectionFuture, metadata);
  }

  @override
  Future<Stream<List<int>>> receive(Map<String, dynamic> connectionInfo) async {
    return await Socket.connect(connectionInfo['host'], connectionInfo['port']);
  } 

  Future<String?> _getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    // Filter to find the primary interface
    // Most devices have a 'wlan' or 'eth' interface
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.address.startsWith('192.168') || addr.address.startsWith('10.')) {
          return addr.address;
        }
      }
    }
    
    // return the first available address if the above doesn't match
    return interfaces.isNotEmpty ? interfaces.first.addresses.first.address : null;
    
  } catch (e) {
    debugPrint('[FTP] Error getting local IP: $e');
    return null;
  }
}
}