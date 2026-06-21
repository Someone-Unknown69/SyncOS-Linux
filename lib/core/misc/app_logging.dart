// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/foundation.dart';

String engineNamespace = '[MAIN]';
void logDebug(String tag, String message) {
  debugPrint('$engineNamespace [$tag] -> $message');
}
