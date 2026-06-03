import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:laptop_controller/core/storage/data/storage_service.dart';

import '../domain/i_connection_manager.dart';
import '../domain/connection_config.dart';
import 'package:flutter/foundation.dart';

class SocketConnectionManager implements IConnectionManager{
  final StorageService _storage;

  SocketConnectionManager(this._storage);

  ServerSocket? _server;
	
  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  
  final BytesBuilder _buffer = BytesBuilder();

  Socket? _client;
  Socket? _pendingSocket;
	bool _isDisconnecting = false;

  // Connection metadata + pairing callback
  final _connectedClientsController = StreamController<int>.broadcast();
  Stream<int> get connectedClientsStream => _connectedClientsController.stream;

  final _pendingClientIPController = StreamController<String?>.broadcast();
  Stream<String?> get pendingClientIPStream => _pendingClientIPController.stream;

  Future<bool> Function(String clientAddress)? onPairingRequested;

  ConnectionStatus _status = ConnectionStatus.inactive;
  ConnectionConfig? _currentConfig;

  // ---------------------------------    Getters    -------------------------------------------- 
  
	@override
  ConnectionStatus get status => _status;

  @override
  ConnectionConfig? get activeConfig => _currentConfig;

  @override
  Stream<String> get rawMessageStream => _messageController.stream;

	@override
  Stream<ConnectionStatus> get connectionStatusStream =>
      Stream<ConnectionStatus>.multi((controller) {
    // Emit current status immediately for new subscribers
    controller.add(_status);
    final sub = _statusController.stream.listen((s) => controller.add(s));
    controller.onCancel = () => sub.cancel();
  });	

  // -----------------------------    Public interface      -------------------------------------

  @override
  Future<void> startServer (ConnectionConfig config) async {
    if (config is TcpConfig) {
      if (_status == ConnectionStatus.active || _status == ConnectionStatus.connected) return;
      
      _currentConfig = config;

      // Mark server as active
      _status = ConnectionStatus.active;
      _statusController.add(_status);

      debugPrint('[Socket] Starting server at port : ${config.port}');

      await _start(config.port);
    } else {
      throw UnsupportedError("This manager only supports TCP connections");
    }
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
    _pendingClientIPController.add(null);
    _connectedClientsController.add(1);

    // the connection is fully accepted/authenticated
    _status = ConnectionStatus.connected;
    _statusController.add(_status);

    Map<String, dynamic> args = {};
    if(op == 'auth') {
      args['token'] = await _storage.getPairingToken();
    }

    try {
      send(op, 'accepted', args);
      if(op == 'auth') {
        debugPrint('[Authentication] Accepted sent');
      } else if (op == 'pair') {
        debugPrint('[Pairing] Accepted sent');
      }
    } catch (e) {
      debugPrint('[Accept] Handshake failed: $e');
    }

  }

	@override
	Future<void> rejectConnection(String op) async {
    if (_pendingSocket != null) {
    
    try {
      send(op, 'rejected', {});
      if(op == 'auth') {
        debugPrint('[Authentication] Rejected sent');
      } else if (op == 'pair') {
        debugPrint('[Pairing] Rejected sent');
      }
    } catch (e) {
      debugPrint('[Reject] Handshake failed: $e');
    }
      _pendingSocket!.destroy();
      _pendingSocket = null;
      _pendingClientIPController.add(null);
    }
  }

  // Public alias used by provider disposal
  Future<void> disconnect() async {
    await stopServer();
    // close controllers to release resources
    try {
      await _connectedClientsController.close();
    } catch (_) {}
    try {
      await _pendingClientIPController.close();
    } catch (_) {}
    try {
      await _messageController.close();
    } catch (_) {}
    try {
      await _statusController.close();
    } catch (_) {}
  }

	// Method to send requests to client
	@override
  void send(String op, String action, Map<String, dynamic> args) {
		if (_client == null) return;
		final payload = jsonEncode({"op": op, "action": action, "args": args});
		_sendRaw(payload);
  }

	/// ---------------------------     Core Implementation    ------------------------------------

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
      _pendingClientIPController.add(socket.remoteAddress.address);
			
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
        if (socket == _pendingSocket) {
          _pendingSocket = null;
          _pendingClientIPController.add(null);
        } else if (socket == _client) {
          _handleDisconnect();
        }
      },
      onError: (e) {
        if (socket == _pendingSocket) {
          _pendingSocket = null;
          _pendingClientIPController.add(null);
        } else if (socket == _client) {
          _handleDisconnect();
        }
      },
    );
  }

	// Method to handle incoming commands from clients
  Future<void> _handleCommand(String command, Socket socket) async {
    try {
      if (command == "PING") {
        debugPrint('Received : $command');
        if (command == "PING") {
          _sendRaw("PONG");
        }
        return;
      }

      final data = jsonDecode(command);
      
      if (socket == _pendingSocket) {
        final args = data['args'];
        final token = await _storage.getPairingToken();
        
        debugPrint('[Authentication] Auth token : ${data['args']} & $token from authenticated client.');
        if (data['op'] == 'auth') {
          
          if(args['token'] == token) {
            debugPrint('[Authentication] Auto-accepting connection from authenticated client.');
            acceptConnection('auth');
          
          } else {
            debugPrint('[Authentication] Rejecting unauthenticated client.');
            rejectConnection('auth');
          }

        } else if (data['op'] == 'pair') {
          
          if (onPairingRequested != null) {
            debugPrint('[Pairing] UI confirmation required...');
            
            // Await the user's decision from the UI
            final confirmed = await onPairingRequested!(_pendingSocket!.remoteAddress.address);
            
            if (confirmed) {
              // Logic to generate/retrieve token from _pairingService
              acceptConnection('pair'); // This sends the 'accepted' + token
            } else {
              rejectConnection('pair');
            }
          } else {
            // If no UI listener, reject for safety
            rejectConnection('pair');
          }
        } else {
          debugPrint('[Authentication] Invalid auth token, rejecting.');
          rejectConnection('Invalid auth token');
        }
        return;
      }
			if(_status == ConnectionStatus.connected) {
				_messageController.add(command);
			}
      return;
    } catch (e) {
      debugPrint("[Handle] Error in handling Command $e");
    }
  }

	void _sendRaw(String data) {
  	if (_client == null && _pendingSocket == null) return;
  	try {
      final socket = _client ?? _pendingSocket!;
      final rawBytes = utf8.encode(data);

      final compressedBytes = gzip.encode(rawBytes);
      final lengthBytes = ByteData(4)..setUint32(0, compressedBytes.length, Endian.big);

      socket.add(lengthBytes.buffer.asUint8List());
      socket.add(compressedBytes);
    } catch (e) {
      debugPrint('[Send] Send raw error: $e');
    }
  }

	// Kill the server and close
  Future<void> _handleDisconnect() async {
    // apparently the client.destory() also calls this, so i have to add a variable barrier
    if (_isDisconnecting == true) return; // Ignore if we are already closing
		_isDisconnecting = true;

    try {
      _client?.destroy();
      _client = null;
      _buffer.clear();
      _connectedClientsController.add(0);

    } finally {
			_status = ConnectionStatus.inactive;
			_statusController.add((_status));
      _isDisconnecting = false; 
    }
  }

}