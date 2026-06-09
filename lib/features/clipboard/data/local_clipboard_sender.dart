import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:laptop_controller/core/hardware/domain/i_local_clipboard.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';

class LocalClipboardSender {
  final IConnectionManager _networkChannel;
  final ILocalClipboard _clipboardChannel;

  StreamSubscription<String>? _clipboardSubscription;

  LocalClipboardSender(
    this._networkChannel,
    this._clipboardChannel,
  );

  void start() {
    _clipboardChannel.init();

    _clipboardSubscription = _clipboardChannel.clipboardUpdates.listen((text) {
      _onClipboardInfo(text);
    });

    debugPrint("[Local Clipboard] Service activated");
  }

  void _onClipboardInfo(String newText) {
    debugPrint('[Local Clipboard] Sending $newText');
    _networkChannel.send('clipboard', '', {'text' : newText});
  }

  void stop() {
    _clipboardSubscription?.cancel();
    _clipboardChannel.dispose();
    debugPrint("[Local Clipboard] Service deactivated");
  }

}