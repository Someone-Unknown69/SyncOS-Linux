import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/features/gamepad/data/linux_controller_driver.dart';
import 'package:laptop_controller/features/gamepad/domain/i_controller_service.dart';

final controllerServiceProvider = Provider<IControllerService> ((ref) {
  final provider = LinuxControllerDriver();
  ref.onDispose(() => provider.dispose());
  return provider;
});