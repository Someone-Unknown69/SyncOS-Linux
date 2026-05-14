import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class PairingService {
  String pairingToken = '';
  final int port;

  PairingService({this.port = 8080});

  String get serviceName => 'PairingService';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final existingToken = prefs.getString('pairing_token');

    if (existingToken != null && existingToken.isNotEmpty) {
      pairingToken = existingToken;
      debugPrint('[Pairing] Restored Security Token: $pairingToken');
    } else {
      // Generate a random token 
      pairingToken = List.generate(16, (index) => Random().nextInt(10)).join();
      await prefs.setString('pairing_token', pairingToken);
      debugPrint('[Pairing] Generated New Security Token: $pairingToken');
    }

    String currentIP = await getLocalIP();
    debugPrint('[Pairing] QR Data for current network: {"ip": "$currentIP", "port": $port, "token": "$pairingToken"}');    
  }

  Future<String> getLocalIP() async {
    // Iterates through network interfaces (Wi-Fi, Ethernet)
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        // Look for an IPv4 address that isn't the loopback (127.0.0.1)
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<void> dispose() async {}
}