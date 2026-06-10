import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:laptop_controller/core/hardware/domain/i_device_info.dart';
import 'package:laptop_controller/core/storage/data/storage_service.dart';
import 'package:laptop_controller/main.dart';
import 'package:laptop_controller/pages/components/popup_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/i_connection_manager.dart';
import '../domain/connection_config.dart';
import 'package:flutter/foundation.dart';

class SocketConnectionManager implements IConnectionManager{
  final StorageService _storage;
  final IDeviceInfo _deviceInfo;

  SocketConnectionManager(this._storage, this._deviceInfo) {
    _setupConnectivityListener();
  }

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  ServerSocket? _server;
  Socket? _client;
  Socket? _pendingSocket;
	
  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _clientConfigController = StreamController<ConnectionConfig?>.broadcast();
  final _serverConfigController = StreamController<ConnectionConfig?>.broadcast();
  
  final BytesBuilder _buffer = BytesBuilder();
	bool _isDisconnecting = false;

  Timer? _broadcastTimer;
  RawDatagramSocket? _udpSocket;
  final int _discoveryPort = 6767;
  final int _defaultPort = 9999;
  
  String _token = "";
  String? _cachedDeviceName;
  String? _cacheDeviceOS;

  // TODO : Remove this and add a notification for confirmation
  Future<bool> showPairingDialog(String ip) async {
    final context = navigatorKey.currentContext;
    
    if (context == null) return false; 
    final completer = Completer<bool>();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppPopupDialog(
        title: 'Accept Connection',
        subtitle: 'Device at $ip is requesting to pair.',
        primaryButtonLabel: 'Accept',
        onPrimaryPressed: () {
          Navigator.pop(context); 
          completer.complete(true); 
        },
        secondaryButtonLabel: 'Reject',
        onSecondaryPressed: () {
          Navigator.pop(context); 
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  ConnectionStatus _status = ConnectionStatus.inactive;
  ConnectionConfig? _serverConfig;
  ConnectionConfig? _clientConfig;

  // ---------------------------------    Getters    -------------------------------------------- 
  
	@override
  ConnectionStatus get status => _status;

  @override
  ConnectionConfig? get activeConfig => _serverConfig;

  ConnectionConfig? get clientConfig => _clientConfig;

  // ---------------------------------    Streams    -------------------------------------------- 

  Stream<ConnectionConfig?> get clientConfigStream => _clientConfigController.stream;
  
  @override 
  Stream<String> get rawMessageStream => _messageController.stream;

  @override
  Stream<ConnectionConfig?> get serverConfigStream =>
      Stream<ConnectionConfig?>.multi((controller) {
    controller.add(_serverConfig);
    final sub = _serverConfigController.stream.listen((c) => controller.add(c));
    controller.onCancel = () => sub.cancel();
  });

	@override
  Stream<ConnectionStatus> get connectionStatusStream =>
      Stream<ConnectionStatus>.multi((controller) {
    // Emit current status immediately for new subscribers
    controller.add(_status);
    final sub = _statusController.stream.listen((s) => controller.add(s));
    controller.onCancel = () => sub.cancel();
  });	

  // -----------------------------    Public interface      -------------------------------------

  // Common entrypoint either by auto connect or pair
  @override
  Future<void> startServer () async {
    if (_server != null) {
      debugPrint('[Socket] Server already running, skipping start');
      return;
    }

    // build config here as , and we will keep updatinng config in auto connect and start pairing loops 
    //if we need to. that config will be stored in storage and ui will listen to server config to display
    // the pairing token will also be generated here and stored on startPairingMode()
    final tcpConfig = await _buildConfig();
    _serverConfig = tcpConfig;
    _serverConfigController.add(_serverConfig);

    if(_serverConfig is! TcpConfig) {
      throw UnsupportedError("Mismatched config protocol");
    }

    debugPrint('[Socket] Starting server at port : ${tcpConfig.port}');

    bool isPaired = await _storage.isPaired;
    // If we are yet to be paired start the pairing broadcast
    if(isPaired) {
      startAutoConnectionBroadcast();
    } else {
      startPairingMode();
    }

    // we start the tcp socket to listen in parallel
    await _start(tcpConfig.port);
  }


  void startAutoConnectionBroadcast() async {
    _stopConnectionBroadcast();

    final token = await _storage.getPairingToken();
    if (token == null || token.isEmpty) {
      debugPrint('[AutoConnect Broadcast] No pairing token found. Skipping autoconnect');
      return;
    }

    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket?.broadcastEnabled = true;

      debugPrint('[AutoConnect Broadcast] Broadcasting autoconnect for paired devices');

      _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (_udpSocket == null || _serverConfig is! TcpConfig) return;

        final tcpConfig = _serverConfig as TcpConfig;
        final String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final liveIP = await _getCurrentLocalIp() ?? '0.0.0.0';

        debugPrint('[Auto Connect] IP: $liveIP');
        if (liveIP != tcpConfig.ip) {
          _serverConfig = TcpConfig(ip: liveIP, port: tcpConfig.port);
          _serverConfigController.add(_serverConfig);

          _udpSocket?.close();
          _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          _udpSocket?.broadcastEnabled = true;
        }

        // signature computation using the pairing token
        final keyBytes = utf8.encode(token);
        final messageBytes = utf8.encode(timestamp);
        final hmac = Hmac(sha256, keyBytes);
        final signature = hmac.convert(messageBytes).toString();

        final Map<String, dynamic> payload = {
          "service": "SyncOS-server",
          "timestamp": timestamp,
          "signature": signature,
          "config": {
            "ip": liveIP,
            "port": tcpConfig.port,
            "type": 'tcp',
          }
        };

        final data = utf8.encode(jsonEncode(payload));
        final broadcastAddress = _calculateSubnetBroadcast(liveIP);

        // Broadcast to the standard local subnet broadcast address
        _udpSocket?.send(
          data, 
          InternetAddress(broadcastAddress), 
          _discoveryPort,
        );
      });
    } catch (e) {
      debugPrint('[AutoConnect Broadcast] Failed to initialize socket: $e');
    }
  }

  void startPairingMode() async {
    stopPairingMode();
    try {
      await generateAndSavePairingToken();

      _udpSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket?.broadcastEnabled = true;

      debugPrint('[Pairing Broadcast] Pairing Mode Active, Visible to all new devices.');

      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_udpSocket == null || _serverConfig is! TcpConfig) return;

        final tcpConfig = _serverConfig as TcpConfig;
        final liveIp = await _getCurrentLocalIp() ?? tcpConfig.ip;

        if (liveIp != tcpConfig.ip) {
          debugPrint('[Pairing Broadcast] Network migration, New IP: $liveIp');
          _serverConfig = TcpConfig(ip: liveIp, port: tcpConfig.port);
          _serverConfigController.add(_serverConfig);

          _udpSocket?.close();
          _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          _udpSocket?.broadcastEnabled = true;
        }

        final Map<String, dynamic> payload = {
          "service": "SyncOS-server",
          "status": "pairing_mode",
          "config": {
            "deviceName" : _cachedDeviceName,
            "deviceOS" : _cachedDeviceName,
            "type": 'tcp',
            "ip": liveIp,
            "port": tcpConfig.port
          }
        };

        final data = utf8.encode(jsonEncode(payload));
        _udpSocket?.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
      });
    } catch (e) {
      debugPrint('[Pairing Broadcast] Failed to start pairing mode beacon: $e');
    }
  }

  Future<void> generateAndSavePairingToken() async {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final token = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    debugPrint('[Pairing Broadcast] New secure pairing token generated: $token');
    _token =  token;
  }

  void stopPairingMode() => _stopConnectionBroadcast();

  void _stopConnectionBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
  }
	
	@override
	Future<void> stopServer() async{
    await _handleDisconnect();
    _server?.close();
    _status = ConnectionStatus.inactive;
		_statusController.add(_status);
  }

	@override
	Future<void> acceptConnection(String op) async { 
    if (_pendingSocket == null) return;

    _client = _pendingSocket;
    _pendingSocket = null;

    // set client config
    _clientConfig = TcpConfig(
      ip: _client!.remoteAddress.address, 
      port: _client!.remotePort
    );

    _clientConfigController.add(_clientConfig);

    // the connection is fully accepted/authenticated
    _status = ConnectionStatus.connected;
    _statusController.add(_status);

    Map<String, dynamic> args = {};
    if(op == 'pair') {
      args['token'] = _token;
      await _storage.setPairingToken(_token);
      await _storage.setClientConfig(_clientConfig!);
    }

    try {
      debugPrint('[Accept] sending accept with $args');
      final payload = jsonEncode({"op": op, "action": "accepted", "args": args});
      _sendRaw(payload, compress: false);
      debugPrint('[$op] Accepted sent');
    } catch (e) {
      debugPrint('[$op] Handshake failed: $e');
    }

    // Stop discovery/autoconnect service
    _stopConnectionBroadcast();

  }

	@override
	Future<void> rejectConnection(String op) async {
    if (_pendingSocket != null) {
      try {
        send(op, 'rejected', {});
        debugPrint('[$op] Rejected sent');
      } catch (e) {
        debugPrint('[Reject] Handshake failed: $e');
      }

      _pendingSocket!.destroy();
      _pendingSocket = null;
    }
  }

  Future<void> disconnect() async {
    await stopServer();
    try { await _serverConfigController.close(); } catch (_) {}
    try { await _clientConfigController.close(); } catch (_) {}
    try { await _messageController.close(); } catch (_) {}
    try { await _statusController.close(); } catch (_) {}
  }

	// Method to send requests to client
	@override
  void send(String op, String action, Map<String, dynamic> args) {
		final payload = jsonEncode({"op": op, "action": action, "args": args});
		_sendRaw(payload);
  }

	/// ---------------------------     Core Implementation    ------------------------------------

  ConnectivityResult? _lastResult;

  void _setupConnectivityListener() {
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final currentResult = results.first;

      if (_lastResult == currentResult) return;
      _lastResult = currentResult;

      if(status == ConnectionStatus.connected) {
        if (currentResult == ConnectivityResult.none) {
          debugPrint('[Network] Detected disconnect');
          _handleDisconnect();
        } else {
          debugPrint('[Network] Detected network change: ${currentResult.name}');
          Future.delayed(const Duration(milliseconds: 500), () => _restartServer());
        }
      }
    });
  }

  Future<TcpConfig> _buildConfig() async {
    final liveIp = await _getCurrentLocalIp() ?? '127.0.0.1';
    int defaultPort = _defaultPort;

    final String deviceName = _cachedDeviceName ??= await _deviceInfo.getDeviceName();
    final String deviceOS = _cacheDeviceOS ??= await _deviceInfo.getOSVersion();
    
    return TcpConfig(
      ip: liveIp, 
      port: defaultPort,
      deviceName: deviceName,
      deviceOS: deviceOS
    );
  }

  String _calculateSubnetBroadcast(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      parts[3] = '255';
      return parts.join('.');
    }
    return '255.255.255.255'; 
  }

	Future<void> _start(int port) async {
		_server = await ServerSocket.bind(InternetAddress.anyIPv4 , port);

		_status = ConnectionStatus.active;
		_statusController.add(_status);


		_server!.listen((Socket socket) {
			debugPrint('[Socket] Client attempting to connect: ${socket.remoteAddress.address}:${socket.remotePort}');
			socket.setOption(SocketOption.tcpNoDelay, true);
			if (_client != null || _pendingSocket != null) {
				debugPrint('[Socket] Rejecting connection: already have a client or pending');
				socket.close();
				return;
			}
      _pendingSocket = socket;
			_buffer.clear();
			_setupSocketListeners(socket);
		});
	}

	// Setting up the socket listener to get client's requests
  void _setupSocketListeners(Socket socket) {
    socket.listen(
      (List<int> data) {
        _buffer.add(data);
        while (_buffer.length >= 4) {
          final bytes = _buffer.toBytes();
          final length = ByteData.view(bytes.buffer).getUint32(0, Endian.big);
          
          if (bytes.length >= 4 + length) {
            final payload = bytes.sublist(4, 4 + length);

            final String jsonString;
            if (payload.length >= 2 && payload[0] == 0x1F && payload[1] == 0x8B) {
              jsonString = utf8.decode(gzip.decode(payload));
            } else {
              jsonString = utf8.decode(payload);
            }

            _handleCommand(jsonString, socket);
            
            _buffer.clear();
            if (bytes.length > 4 + length) {
              _buffer.add(bytes.sublist(4 + length));
            }
          } else {
            break; // need more data
          }
        }
      },
      onDone: () {
        debugPrint("[ON DONE] This is doing that shit");
        _cleanupSocket(socket);
      },
      onError: (e) {
        debugPrint("[ON ERROR] This is doing that shit $e");
        _cleanupSocket(socket);
      },
    );
  }

  void _cleanupSocket(Socket socket) {
    debugPrint("[Socket] Cleaning up socket: ${socket.remoteAddress.address}");
    
    try {
      socket.destroy();
    } catch (e) {
      debugPrint("[Socket] Cleanup error: $e");
    }

    if (socket == _pendingSocket) {
      _pendingSocket = null;
    } else if (socket == _client) {
      _handleDisconnect();
    }
  }

  Future<void> _restartServer() async {
    debugPrint('[Network] Re-initializing server stack...');
    await _server?.close();
    _server = null;

    await _handleDisconnect(); 
  }

	// Method to handle incoming commands from clients
  Future<void> _handleCommand(String command, Socket socket) async {
    try {
      if (command == "PING") {
        debugPrint('Received : $command');
        _sendRaw("PONG");
        return;
      }

      final data = jsonDecode(command);
      
      if (socket == _pendingSocket) {
        final args = data['args'];
        final token = await _storage.getPairingToken();
        
        debugPrint('[Authentication] Method : ${data['op']}, Auth token : ${data['args']} & $token from authenticated client.');
        if (data['op'] == 'auth') {
          if(args['token'] == token) {
            debugPrint('[Authentication] Auto-accepting connection from authenticated client.');
            acceptConnection('auth');
          
          } else {
            debugPrint('[Authentication] Rejecting unauthenticated client.');
            rejectConnection('auth');
          }

        } else if (data['op'] == 'pair') {
          debugPrint('[Pairing] UI confirmation required...');

          // Await the user's decision from the UI
          final confirmed = await showPairingDialog(_pendingSocket!.remoteAddress.address);
          
          if (confirmed) {
            // Logic to generate/retrieve token from _pairingService
            acceptConnection('pair'); // This sends the 'accepted' + token
          } else {
            rejectConnection('pair');
          }
        } else {
          debugPrint('[Authentication] Invalid auth token, rejecting.');
          rejectConnection('Invalid auth token');
        }
        return;
      }

      if(data['op'] == 'unpair') {
        await _clearConnectionInfo();
        await _clearConnectionInfo();
  
        _client?.destroy();
        _client = null;
        
        _stopConnectionBroadcast();
        startPairingMode();
        debugPrint('[Socket] Remote device unpaired');
        return;
      }

			if(_status == ConnectionStatus.connected) {
				_messageController.add(command);
			}
      return;
    } catch (e) {
      debugPrint("[Server] Error in handling Command $e");
    }
  }

	// Update this signature and implementation
  void _sendRaw(String msg, {bool compress = true}) {
    try {
      final rawBytes = utf8.encode(msg);
      
      final List<int> payload = compress ? gzip.encode(rawBytes) : rawBytes;

      final lengthBytes = ByteData(4)..setUint32(0, payload.length, Endian.big);
      
      final socket = _client ?? _pendingSocket!; 
      
      socket.add(lengthBytes.buffer.asUint8List());
      socket.add(payload);
    } catch (e) {
      debugPrint('[Server/Client] Send raw error: $e');
    }
  }

	// Kill the server and close
  Future<void> _handleDisconnect() async {
    if (_isDisconnecting == true) return; 
    _isDisconnecting = true;

    try {
      _client?.destroy();
      _client = null;
      _buffer.clear();

      _clientConfig = null;
      _clientConfigController.add(null);

      if(_server == null) {
        // when called by restart
        startServer();
      } else {
        // when called to reset
        bool isPaired = await _storage.isPaired;
        if(isPaired) {
          startAutoConnectionBroadcast();
        } else {
          startPairingMode();
        }
      }

    } finally {
      _status = ConnectionStatus.active;
      _statusController.add((_status));
      _isDisconnecting = false; 
    }
  }

  Future<void> _clearConnectionInfo() async {
    try {
      await _storage.clearPairingToken();
      await _storage.removeClientConfig();

      debugPrint('[Socket] Paired device Info cleared successfully');
    } catch (e) {
      debugPrint('[Socket] Error while clearing connection info of unpaired device');
    }
  }

  Future<String?> _getCurrentLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('en') ||
            interface.name.toLowerCase().contains('eth')) {
          if (interface.addresses.isNotEmpty) {
            return interface.addresses.first.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('[Server] Error resolving local IP: $e');
    }
    return null;
  }

}