import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    
    debugPrint('[Pairing] QR Data to generate: {"ip": "YOUR_IP", "port": $port, "token": "$pairingToken"}');
  }

  // Use this for the HTTP Handshake
  Response handleHandshake(Request request) {
    // In a production app, verify the token sent by the mobile app here
    return Response.ok(jsonEncode({'status': 'authorized'}));
  }

  Future<void> dispose() async {}
}