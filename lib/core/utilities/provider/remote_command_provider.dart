import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/utilities/data/linux_command.dart';
import 'package:laptop_controller/core/utilities/domain/i_remote_command.dart';

final remoteCommandProvider = Provider<IRemoteCommand>((ref) {
  return LinuxCommand();
});