abstract class ConnectionConfig {
  String get type;
  Map<String, dynamic> toJson();

  // Global Registry: Maps 'type' string to a factory function
  static final Map<String, ConnectionConfig Function(Map<String, dynamic>)> _registry = {
    'tcp': TcpConfig.fromJson,
    // Add new types here
  };

  // The global conversion method
  static ConnectionConfig fromMap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || !_registry.containsKey(type)) {
      throw Exception("Unsupported or missing connection type: $type");
    }
    return _registry[type]!(data);
  }
}

class TcpConfig extends ConnectionConfig {
  @override
  String get type => 'tcp';

  final int port;
  final String ip;

  int get getPort => port;

  TcpConfig({required this.port, required this.ip});

  @override
  Map<String, dynamic> toJson() => {'type': type, 'port': port, 'ip':ip};

  factory TcpConfig.fromJson(Map<String, dynamic> json) => TcpConfig(
        port: json['port'] ?? 8080,
        ip: json['ip'] ?? '0.0.0.0',
      );
}

