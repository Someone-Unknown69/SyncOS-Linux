// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:syncos_linux/core/hardware/domain/i_battery_info.dart';
import 'package:syncos_linux/core/hardware/domain/i_device_info.dart';
import '../domain/i_local_battery_sender.dart';


class BatteryMonitorService implements IBatteryMonitorService {
  final IConnectionManager _connectionManager;
  final IBatteryInfo _batteryInfo;
  final IDeviceInfo _deviceInfo;
  
  StreamSubscription? _stateSubscription;

  BatteryMonitorService(this._connectionManager, this._batteryInfo, this._deviceInfo);

  Future<int> getBatteryLevel() async => _batteryInfo.getLevel();
  Future<bool> getBatteryStatus() async => _batteryInfo.isCharging();

  Future<String> getDeviceName() async {
    return await _deviceInfo.getDeviceName();
  }

  @override
  Future<void> start() async {
    if (_stateSubscription != null) return;

    final name = await getDeviceName();
    _connectionManager.send("device_info", '', {'name': name});

    await _sendBatteryUpdate();

    _stateSubscription = _batteryInfo.onStateChanged.listen((_) async {
      await _sendBatteryUpdate();
    });
  }

  @override
  void stop() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
  }

  Future<void> _sendBatteryUpdate() async {
    final level = await getBatteryLevel();
    final isCharging = await getBatteryStatus();
    
    _connectionManager.send('battery_info', '', {
      'level': level,
      'status': isCharging,
    });
  }

  @override
  void dispose() {
    stop();
  }
}