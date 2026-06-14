// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/utilities/provider/local_clipboard_provider.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/features/clipboard/data/local_clipboard_sender.dart';

final localClipboardSenderProvider = Provider<LocalClipboardSender>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final localClipboardInfo = ref.watch(localClipboardInfoProvider); 

  return LocalClipboardSender(
    connectionManager,
    localClipboardInfo,
  );
});