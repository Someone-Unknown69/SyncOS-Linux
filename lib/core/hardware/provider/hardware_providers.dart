import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/hardware/data/linux_clipboard.dart';
import 'package:laptop_controller/core/hardware/domain/i_local_clipboard.dart';

import '../domain/i_battery_info.dart';
import '../data/battery_info_impl.dart';
import '../domain/i_device_info.dart';
import '../data/device_info_impl.dart';

// TODO : Add more info like RAM and Storage in future updates

final batteryInfoProvider = Provider<IBatteryInfo>((ref) {
  return BatteryInfoImpl();
});

final deviceInfoProvider = Provider<IDeviceInfo>((ref) {
  return DeviceInfoImpl();
});

final localClipboardInfoProvider = Provider<ILocalClipboard>((ref) {
  return LinuxClipboard();
});