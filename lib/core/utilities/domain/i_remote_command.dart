// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

abstract class IRemoteCommand {
  void runCommand(String command, bool isRoot);
}