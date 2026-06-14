// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/remote_battery_model.dart';

part 'remote_battery_state.g.dart';

@riverpod
class BatteryNotifier extends _$BatteryNotifier {
  @override
  BatteryState build() => const BatteryState();
  
  void update(int level, bool charging) => state = BatteryState(level: level, isCharging: charging);
}
