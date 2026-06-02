import 'dart:async';
import 'dart:io';
import 'package:laptop_controller/core/hardware/domain/i_device_info.dart';

class DeviceInfoImpl implements IDeviceInfo {
  String _deviceName = 'Unknown';
  String _osVersion = 'Unknown';

  @override
  Future<String> getDeviceName() async {
    await _refreshInfo();
    return _deviceName;
  }

  @override
  Future<String> getOSVersion() async {
    await _refreshInfo();
    return _osVersion;
  }

  Future<void> _refreshInfo() async {
    final name = _buildDeviceName();
    final osVersion = _buildOSVersion();

    if (name != _deviceName || osVersion != _osVersion) {
      _deviceName = name;
      _osVersion = osVersion;
    }
  }

  String _buildDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Unknown';
    }
  }

  String _buildOSVersion() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown';
    }
  }
}