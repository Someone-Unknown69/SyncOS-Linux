// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/remote_device_info_model.dart';

part 'remote_device_info_state.g.dart';

@riverpod
class DeviceInfoNotifier extends _$DeviceInfoNotifier{
  @override
  DeviceInfoState build() => const DeviceInfoState();
  
  void update(String name) => state = DeviceInfoState(name : name);
}
