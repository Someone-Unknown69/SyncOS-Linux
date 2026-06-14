// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';

abstract class ILocalClipboard {
  void init();
  Stream<String> get clipboardUpdates;
  void dispose();
}