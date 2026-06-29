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
    final metadata = {'port': server.port, 'host': localIp ?? '127.0.0.1'};

    debugPrint(
      '[FTP] Server bound on port ${server.port}. Waiting for connection...',
    );

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

      final virtualInterfaceKeywords = [
        'docker',
        'vboxnet',
        'br-',
        'veth',
        'virbr',
        'any',
        'lo',
      ];

      for (var interface in interfaces) {
        final nameLower = interface.name.toLowerCase();

        if (virtualInterfaceKeywords.any(
          (keyword) => nameLower.contains(keyword),
        )) {
          continue;
        }

        for (var addr in interface.addresses) {
          final ip = addr.address;

          // Validate against all three official RFC 1918 Private IPv4 address blocks
          // Class A: 10.0.0.0 – 10.255.255.255
          // Class B: 172.16.0.0 – 172.31.255.255
          // Class C: 192.168.0.0 – 192.168.255.255
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            return ip;
          }

          if (ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              final secondOctet = int.tryParse(parts[1]);
              if (secondOctet != null &&
                  secondOctet >= 16 &&
                  secondOctet <= 31) {
                return ip;
              }
            }
          }
        }
      }

      // Fallback: If no ideal physical private IP matches, grab the first non-virtual link
      for (var interface in interfaces) {
        final nameLower = interface.name.toLowerCase();
        if (!virtualInterfaceKeywords.any(
          (keyword) => nameLower.contains(keyword),
        )) {
          if (interface.addresses.isNotEmpty) {
            return interface.addresses.first.address;
          }
        }
      }

      return interfaces.isNotEmpty
          ? interfaces.first.addresses.first.address
          : null;
    } catch (e) {
      debugPrint('[FTP] Error getting local IP: $e');
      return null;
    }
  }
}

