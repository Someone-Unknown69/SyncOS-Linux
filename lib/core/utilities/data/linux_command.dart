import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:laptop_controller/core/utilities/domain/i_remote_command.dart';

class LinuxCommand implements IRemoteCommand{
  
  @override
  Future<ProcessResult> runCommand(
    String command,
    bool isRoot,
  ) async {
    final executable = isRoot ? 'sudo' : 'bash';
    debugPrint("DIS WORK");
    
    final arguments = isRoot 
        ? ['bash', '-c', command] 
        : ['-c', command];

    return await Process.run(executable, arguments);
  }
}