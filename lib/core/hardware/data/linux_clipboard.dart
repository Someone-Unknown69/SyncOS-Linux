import 'dart:async';
import 'package:flutter/services.dart';
import 'package:laptop_controller/core/hardware/domain/i_local_clipboard.dart';
import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/foundation.dart';

// TODO : IMplement this in future updates

class LinuxClipboard with ClipboardListener implements ILocalClipboard{
  
  final StreamController<String> _controller = StreamController<String>.broadcast();
  String _lastSeenText = '';

  @override
  void init () {
    // clipboardWatcher.addListener(this);
    // clipboardWatcher.start();

    // debugPrint('[Linux Clipboard] Started');
  }

  @override
  Stream<String> get clipboardUpdates => _controller.stream;

  @override
  void onClipboardChanged() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      
      if (data != null && data.text != null) {
        final String cleanText = data.text!.trim();
        
        if (cleanText.isNotEmpty && cleanText != _lastSeenText) {
          _lastSeenText = cleanText;
          debugPrint('[Linux Clipboard] sent some');
          _controller.add(cleanText);
        }
      }
    } catch (e) {
      debugPrint('Failed processing event payload: $e');
    }
  }


  @override 
  void dispose() {
    clipboardWatcher.removeListener(this);
    clipboardWatcher.stop();
    _controller.close();
  }
}