enum AppBatteryState { charging, discharging, full, unknown }

abstract class IBatteryInfo {
  int getLevel();
  bool isCharging();
  AppBatteryState currentState();
  Stream<(AppBatteryState,int)> get onStateChanged;
}