import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/remote_battery_model.dart';

part 'remote_battery_state.g.dart';

@riverpod
class BatteryNotifier extends _$BatteryNotifier {
  @override
  BatteryState build() => const BatteryState();
  
  void update(int level, bool charging) => state = BatteryState(level: level, isCharging: charging);
}
