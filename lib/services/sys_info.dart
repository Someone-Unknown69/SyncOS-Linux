import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:io';
import 'dart:async';

// -------------------------------------    sys_info     -----------------------------------------------

class SystemDataService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();

  Future<Map<String, dynamic>> getFullDeviceStatus() async {
    // Get Battery Data (Dynamic)
    final int level = await _battery.batteryLevel;
    final BatteryState state = await _battery.batteryState;
    final bool charging = state == BatteryState.charging;

    // Get Device Identity (Static)
    Map<String, dynamic> common = {};
    if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await _deviceInfo.linuxInfo;
      common = {
        'name': linuxInfo.name,
        'version': linuxInfo.versionId,
        'id': linuxInfo.machineId,
        'os': 'Linux',
      };
    } else if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      common = {
        'name': androidInfo.model,
        'version': androidInfo.version.release,
        'id': androidInfo.id,
        'os': 'Android',
      };
    }

    // Merge everything into one response
    return {
      ...common,
      'battery': level,
      'isCharging': charging,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'status'
    };
  }
}
