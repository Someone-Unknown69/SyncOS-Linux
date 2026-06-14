// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:syncos_linux/core/utilities/domain/i_local_clipboard.dart';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';

class LocalClipboardSender {
  final IConnectionManager _networkChannel;
  final ILocalClipboard _clipboardChannel;

  StreamSubscription<String>? _clipboardSubscription;

  LocalClipboardSender(
    this._networkChannel,
    this._clipboardChannel,
  );

  void start() {
    
  }

  void onClipboardInfo(String newText) {
    debugPrint('[Local Clipboard] Sending $newText');
    _networkChannel.send('clipboard', '', {'text' : newText});
  }

  void stop() {
    _clipboardSubscription?.cancel();
    _clipboardChannel.dispose();
    debugPrint("[Local Clipboard] Service deactivated");
  }

}