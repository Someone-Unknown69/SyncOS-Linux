// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import '../../../core/hardware/provider/hardware_providers.dart';
import '../data/local_battery_sender.dart';

final batteryMonitorProvider = Provider<BatteryMonitorService>((ref) {
  final connection = ref.watch(connectionManagerProvider);
  final batteryInfo = ref.watch(batteryInfoProvider);
  final deviceInfo = ref.watch(deviceInfoProvider);
  
  final service = BatteryMonitorService(connection, batteryInfo, deviceInfo);
  
  ref.onDispose(() => service.dispose());
  
  return service;
});