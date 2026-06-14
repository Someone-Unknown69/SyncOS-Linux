// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'dart:io';

abstract class IFileTransferManager {
  // Returns a sink to push data out to the peer
  Future<(Future<Socket>, Map<String, dynamic>)> send();
  
  // Returns a stream to read data incoming from the peer + the metadata to establish connection
  Future<Stream<List<int>>> receive(Map<String, dynamic> connectionInfo);
}