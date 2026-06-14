// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:io';
import 'package:syncos_linux/core/hardware/domain/i_battery_info.dart';

class BatteryInfoImpl implements IBatteryInfo {
  int _lastLevel = 0;
  AppBatteryState _lastState = AppBatteryState.unknown;

  final String _batPath = '/sys/class/power_supply/BAT0';

  @override
  int getLevel() {return _lastLevel;}

  @override
  bool isCharging() => (_lastState) == AppBatteryState.charging;


  @override
  AppBatteryState currentState() {return _lastState;}

  @override
  Stream<(AppBatteryState, int)> get onStateChanged async* {
    while (true) {
      final info = await _readBattery();

      if (info != null) {
        final level = info.level;
        final AppBatteryState state =
          (level == 100) ? AppBatteryState.full :
            ((info.isCharging) ? AppBatteryState.charging : AppBatteryState.discharging);

        if (_lastLevel != level || state != _lastState) {
          _lastLevel = level;
          _lastState = state;
          yield (state, level);
        }
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }

  Future<({int level, bool isCharging})?> _readBattery() async {
    try {
      final capacityFile = File('$_batPath/capacity');
      final statusFile = File('$_batPath/status');

      final level = int.tryParse((await capacityFile.readAsString()).trim()) ?? 0;
      final status = (await statusFile.readAsString()).trim().toLowerCase();

      return (level: level, isCharging: status == 'charging');
    } catch (e) {
      return null;
    }
  }
}