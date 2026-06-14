// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/theme/theme_notifier.dart';
import 'package:syncos_linux/core/storage/domain/models/app_settings.dart';

final themeProvider = NotifierProvider<ThemeNotifier, AppSettings>(ThemeNotifier.new);