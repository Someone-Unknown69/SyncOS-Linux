// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:syncos_linux/core/utilities/domain/clipboard_object_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_clipboard_notifier.g.dart';

@Riverpod(keepAlive: true)
class RemoteClipboardNotifier extends _$RemoteClipboardNotifier {
  @override
  ClipboardObject? build() {
    return null;
  }

  void addClipboardContent(String content) {
    // Update the state with a new instance
    state = ClipboardObject(content: content);
  }
}