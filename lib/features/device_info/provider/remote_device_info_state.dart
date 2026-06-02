import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/remote_device_info_model.dart';

part 'remote_device_info_state.g.dart';

@riverpod
class DeviceInfoNotifier extends _$DeviceInfoNotifier{
  @override
  DeviceInfoState build() => const DeviceInfoState();
  
  void update(String name) => state = DeviceInfoState(name : name);
}
