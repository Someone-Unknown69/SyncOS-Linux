// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import '../domain/connection_config.dart';

// Domain interface for connection manager 
// Any connection services must match the following blueprint
enum ConnectionStatus {
  connected,   // Fully authenticated, connection is active and authorized
  inactive,    // Server is inactive but not connected
  active,      // Server is active
}

abstract class IConnectionManager {
  // streams
  Stream<String> get rawMessageStream;
  Stream<ConnectionStatus> get connectionStatusStream;
  Stream<ConnectionConfig?> get serverConfigStream;

  // status
  ConnectionConfig? get activeConfig;
  ConnectionStatus get status;

  // connection
  Future<void> startServer();
  Future<void> stopServer();

  // pairing
  Future<void> unpair();

  // Authorization
  Future<void> acceptConnection(String op);
  Future<void> rejectConnection(String op);

  // The implementation handles the serialization.
  void send(String op, String action, Map<String, dynamic> args);
}