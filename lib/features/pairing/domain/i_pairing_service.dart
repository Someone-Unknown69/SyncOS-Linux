import 'package:laptop_controller/core/network/domain/connection_config.dart';

abstract class IPairingService {
  Future<void> initialize(ConnectionConfig config);

  Future<String> getLocalIP();

  Future<void> dispose();
}
