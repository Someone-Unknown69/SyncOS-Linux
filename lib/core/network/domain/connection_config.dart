// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

abstract class ConnectionConfig {
  final String? deviceName;
  final String? deviceOS;

  ConnectionConfig({this.deviceName, this.deviceOS});

  String get type;
  Map<String, dynamic> toJson();

  static final Map<String, ConnectionConfig Function(Map<String, dynamic>)> _registry = {
    'tcp': TcpConfig.fromJson,
  };

  factory ConnectionConfig.fromMap(Map<String, dynamic> data) {
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

  TcpConfig({
    required this.port,
    required this.ip,
    super.deviceName,
    super.deviceOS,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'port': port,
        'ip': ip,
        if (deviceName != null) 'deviceName': deviceName,
        if (deviceOS != null) 'deviceOS': deviceOS,
      };

  factory TcpConfig.fromJson(Map<String, dynamic> json) => TcpConfig(
        port: json['port'] ?? 8080,
        ip: json['ip'] ?? '0.0.0.0',
        deviceName: json['deviceName'], 
        deviceOS: json['deviceOS'],   
      );
}