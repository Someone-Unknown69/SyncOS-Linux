// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/file_service_impl.dart';
import '../domain/i_file_service.dart';

final fileServiceProvider = Provider<IFileService>((ref) {
  return FileServiceImpl();
});