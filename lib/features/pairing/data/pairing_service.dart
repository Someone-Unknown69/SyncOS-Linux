import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/storage/data/storage_service.dart';
import 'package:laptop_controller/features/pairing/domain/i_pairing_service.dart';

class PairingService implements IPairingService {
  final StorageService _storage;

  PairingService(
    this._storage,
  );

  @override
  String pairingToken = '';

  @override
  Future<void> initialize(ConnectionConfig config) async {
    final existingToken = await _storage.getPairingToken();

    if (existingToken != null && existingToken.isNotEmpty) {
      pairingToken = existingToken;
      debugPrint('[Pairing] Restored Security Token: $pairingToken');
    } else {
      pairingToken = List.generate(16, (index) => Random().nextInt(10)).join();
      await _storage.setPairingToken(pairingToken);
      debugPrint('[Pairing] Generated New Security Token: $pairingToken');
    }

    final currentIP = await getLocalIP();
    debugPrint('[Pairing] QR Data for current network: ${_buildPairingData(currentIP, config)}');
  }

  Map<String, dynamic> _buildPairingData(String currentIP, ConnectionConfig config) {
    return {
      'ip': currentIP,
      'config': config.toJson(),
      'token': pairingToken,
    };
  }

  @override
  Future<String> getLocalIP() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  @override
  Future<void> dispose() async {}
}
