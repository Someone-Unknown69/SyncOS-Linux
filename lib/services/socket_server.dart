import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'device_info.dart';
import 'pairing_service.dart';
import 'handle_request.dart';
import 'Music/music_sending.dart';
import 'Music/mpris_service.dart';

// --------------------------------    Socket Class      -------------------------------------------------
 
class SocketServer extends ChangeNotifier{
  // ------------------------------    Class Variables    ------------------------------------------------
  ServerSocket? _server;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Socket? _client;
  Socket? _pendingSocket;
  bool _isDisconnecting = false;
  
  final BytesBuilder _buffer = BytesBuilder();

  // --------------------------------     Services       ----------------------------------------
  final PairingService _pairingService;
  final MediaPoller _mediaPoller = MediaPoller();
  final BatteryMonitorServiceLinux _batteryMonitorServiceLinux = BatteryMonitorServiceLinux();
  final requestHandler = HandleRequest();
  final MprisService _mprisService = MprisService.instance;

  // -------------------------------      Instance       --------------------------------------
  static SocketServer? _instance;
  static SocketServer get instance => _instance!;
  factory SocketServer({required PairingService pairingService}) {
    _instance ??= SocketServer._internal(pairingService);
    return _instance!;
  }
  SocketServer._internal(this._pairingService);

  // -------------------------------    Connection Information    ---------------------------------
  final ValueNotifier<int> connectedClients = ValueNotifier<int>(0);
  final ValueNotifier<String?> pendingClientIP = ValueNotifier<String?>(null);


  // ---------------------------------    Getters    -------------------------------------------- 
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  String? get connectedClientIP => _client?.remoteAddress.address;

  // --------------------------------     Methods    --------------------------------------------

  // Asynchronous method to start server and listen for connections
  Future<void> startServer(int port) async {
    try {
      debugPrint('[Socket] Starting server on port $port...');

      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

      connectionStatus.value = true;
      debugPrint('[Socket] Server started successfully');

      _server!.listen((Socket socket) {
        debugPrint('[Socket] Client attempting to connect: ${socket.remoteAddress.address}:${socket.remotePort}');
        socket.setOption(SocketOption.tcpNoDelay, true);
        if (_client != null || _pendingSocket != null) {
          debugPrint('[Socket] Rejecting connection: already have a client or pending');
          socket.close();
          return;
        }
        _pendingSocket = socket;
        pendingClientIP.value = socket.remoteAddress.address;
        
        _buffer.clear();
        _setupSocketListeners(socket);

        notifyListeners();
      });

    } catch (e) {
      connectionStatus.value = false;
      debugPrint('[Socket] Error while starting server: $e');
    }
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
            final jsonString = utf8.decode(payload);
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
          pendingClientIP.value = null;
          notifyListeners();
        } else if (socket == _client) {
          _handleDisconnect();
        }
      },
      onError: (e) {
        if (socket == _pendingSocket) {
          _pendingSocket = null;
          pendingClientIP.value = null;
          notifyListeners();
        } else if (socket == _client) {
          _handleDisconnect();
        }
      },
    );
  }

  Future<void> acceptConnection() async { 
    if (_pendingSocket == null) return;

    _client = _pendingSocket;
    _pendingSocket = null;
    pendingClientIP.value = null;
    connectedClients.value = 1;

    try {
      _sendRaw('ACCEPTED');
    } catch (e) {
      debugPrint('[Pairing] Handshake failed: $e');
    }

    // start all the services
    await _startServices();

    notifyListeners();
  }

  void rejectConnection() {
    if (_pendingSocket != null) {
      try {
        final jsonData = utf8.encode('REJECTED');
        final lengthBytes = ByteData(4)..setUint32(0, jsonData.length, Endian.big);
        _pendingSocket!.add(lengthBytes.buffer.asUint8List());
        _pendingSocket!.add(jsonData);
      } catch (e) {
        debugPrint('[Reject] Failed to send reject response: $e');
      }
      _pendingSocket!.destroy();
      _pendingSocket = null;
      pendingClientIP.value = null;
      notifyListeners();
    }
  }

  // Method to stop the server
  Future<void> stopServer() async{
    await _handleDisconnect();
    _server?.close();
    connectionStatus.value = false;
  }

  // Kill the server and close
  Future<void> _handleDisconnect() async {
    // apparently the client.destory() also calls this, so i have to add a variable barrier
    if (_isDisconnecting) return; // Ignore if we are already closing
    _isDisconnecting = true;

    try {
      await _stopServices();
      _client?.destroy();
      _client = null;
      _buffer.clear();
      connectedClients.value = 0;
      notifyListeners();
    } finally {
      _isDisconnecting = false; 
    }
  }


  // --------------------------    Initializing all services    -------------------------------------
  Future<void> _startServices() async {
    try {
      requestHandler.setMediaPoller(_mediaPoller);
      _mediaPoller.start(send);
      _batteryMonitorServiceLinux.start(); 
      debugPrint('[Socket] Services started successfully');
    } catch (e) {
      debugPrint('[Socket] Error in starting servies : $e');
    }
  }

  Future<void> _stopServices() async {
    try {
      _mediaPoller.dispose();
      _batteryMonitorServiceLinux.dispose();
      _mprisService.reset();

      debugPrint('[Socket] Services stopped successfully');
    } catch (e) {
      debugPrint('[Socket] Error in stopping servies : $e');
    }
  }

  // ----------------------------    handling + sending commands    -------------------------------

  // Method to handle incoming commands from clients
  void _handleCommand(String command, Socket socket) {
    try {
      if (command == "PING" || command == "ACCEPTED" || command == "REJECTED") {
        debugPrint('Received : $command');
        if (command == "PING") {
          _sendRaw("PONG");
        }
        return;
      }

      final data = jsonDecode(command);
      
      if (socket == _pendingSocket) {
        if (data['op'] == 'auth' && data['token'] == _pairingService.pairingToken) {
          debugPrint('[Pairing] Auto-accepting connection from authenticated client.');
          acceptConnection();
        } else {
          debugPrint('[Pairing] Invalid auth token, rejecting.');
          rejectConnection();
        }
        return;
      }
      debugPrint('[Handle] Received command: $command');

      requestHandler.handle(command);
      return;
    } catch (e) {
      debugPrint("[Handle] Error in handling Command $e");
    }
  }

  // Method to send requests to client
  void send(String op, String action, Map<String, dynamic> args) {
    try {
      final request = {
        "op": op,
        "action" : action,
        "args": args,
        "id": DateTime.now().millisecondsSinceEpoch,
      };

      if (_client == null) return;

      final jsonData = utf8.encode(jsonEncode(request));
      final lengthBytes = ByteData(4)..setUint32(0, jsonData.length, Endian.big);
      
      _client!.add(lengthBytes.buffer.asUint8List());
      _client!.add(jsonData);
    } catch (e) {
      debugPrint('[Send] Send error: $e');
      _handleDisconnect();
    }
  }

  void _sendRaw(String data) {
    if (_client == null && _pendingSocket == null) return;
    try {
      final socket = _client ?? _pendingSocket!;
      final jsonData = utf8.encode(data);
      final lengthBytes = ByteData(4)..setUint32(0, jsonData.length, Endian.big);
      socket.add(lengthBytes.buffer.asUint8List());
      socket.add(jsonData);
    } catch (e) {
      debugPrint('[Send] Send raw error: $e');
    }
  }
}


