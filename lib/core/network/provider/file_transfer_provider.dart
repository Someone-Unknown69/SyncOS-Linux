// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

// lib/features/file_transfer/logic/file_transfer_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tcp_transfer_service.dart';
import '../domain/i_file_transfer_manager.dart';

final fileTransferTransportProvider = Provider<IFileTransferManager>((ref) {
  return TcpTransferTransport();
});