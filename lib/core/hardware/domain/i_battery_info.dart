// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

enum AppBatteryState { charging, discharging, full, unknown }

abstract class IBatteryInfo {
  int getLevel();
  bool isCharging();
  AppBatteryState currentState();
  Stream<(AppBatteryState,int)> get onStateChanged;
}