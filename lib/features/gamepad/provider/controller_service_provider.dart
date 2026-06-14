// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/features/gamepad/data/linux_controller_driver.dart';
import 'package:syncos_linux/features/gamepad/domain/i_controller_service.dart';

final controllerServiceProvider = Provider<IControllerService> ((ref) {
  final provider = LinuxControllerDriver();
  ref.onDispose(() => provider.dispose());
  return provider;
});