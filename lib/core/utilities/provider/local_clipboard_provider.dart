// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/utilities/data/linux_clipboard.dart';
import 'package:syncos_linux/core/utilities/domain/i_local_clipboard.dart';

final localClipboardInfoProvider = Provider<ILocalClipboard>((ref) {
  return LinuxClipboard();
});