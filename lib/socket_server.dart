import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'services/music.dart';
import 'services/battery_info.dart';
import 'services/http_server.dart';
import 'pairing_service.dart';

// --------------------------------    Socket Class      -------------------------------------------------
 
class SocketServer extends ChangeNotifier{
  // ------------------------------    Class Variables    ------------------------------------------------
  ServerSocket? _server;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final _messageController = StreamController<String>.broadcast();
  Socket? _client;
  Socket? _pendingSocket;
  
  final BytesBuilder _buffer = BytesBuilder();

  // This is the template for any request sent to the other device
  Map<String, dynamic> createRequest({
    required String op,
    Map<String, dynamic>? args,
  }) {
    return {
      "op": op,           // Operation type                    
      "args": args,        // arguments  
      "id": DateTime.now().millisecondsSinceEpoch, // Sequence number
    };
  }

  // --------------------------------     Services       ----------------------------------------
  final MediaPoller _mediaPoller = MediaPoller();
  final BatteryMonitorServiceLinux _batteryMonitorServiceLinux = BatteryMonitorServiceLinux();
  SimpleHttpServer? _httpServer;
  final PairingService _pairingService;

  // ----------------------------  Client  Device Information    ---------------------------------
  final ValueNotifier<String>  deviceName = ValueNotifier<String>(Platform.localHostname);
  final ValueNotifier<int> connectedClients = ValueNotifier<int>(0);
  final ValueNotifier<String?> pendingClientIP = ValueNotifier<String?>(null);

  SocketServer({required PairingService pairingService}) : _pairingService = pairingService;

  // ---------------------------------    Getters    -------------------------------------------- 
  Stream<String> get messageStream => _messageController.stream;

  // --------------------------------     Methods    --------------------------------------------
  // Asynchronous method to start server and listen for connections
  Future<void> startServer(int port) async {
    try {
      debugPrint('Starting server on port $port...');
      
      // Start HTTP Server
      _httpServer = SimpleHttpServer(port: port + 1, pairingToken: _pairingService.pairingToken);
      await _httpServer!.start();

      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

      connectionStatus.value = true;
      debugPrint('Server started successfully');

      _server!.listen((Socket socket) {
        debugPrint('Client attempting to connect: ${socket.remoteAddress.address}:${socket.remotePort}');
        if (_client != null || _pendingSocket != null) {
          debugPrint('Rejecting connection: already have a client or pending');
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
      debugPrint('Error while starting server: $e');
    }
  }

  // Method to send requests to client
  void send(String op, Map<String, dynamic> args) {
    if (op == 'albumArt_internal') {
      _httpServer?.updateAlbumArt(args['albumArt'] ?? '');
      return; // Do not send over socket
    }

    if (_client == null) return;

    try {
      final request = {
        "op": op,
        "args": args,
        "id": DateTime.now().millisecondsSinceEpoch,
      };

      final jsonData = utf8.encode(jsonEncode(request));
      final lengthBytes = ByteData(4)..setUint32(0, jsonData.length, Endian.big);
      
      _client!.add(lengthBytes.buffer.asUint8List());
      _client!.add(jsonData);
    } catch (e) {
      debugPrint('Send error: $e');
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
      debugPrint('Send raw error: $e');
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
      debugPrint('Handshake failed: $e');
    }

    _mediaPoller.start(send);
    _batteryMonitorServiceLinux.start(send); 

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
        debugPrint('Failed to send reject response: $e');
      }
      _pendingSocket!.destroy();
      _pendingSocket = null;
      pendingClientIP.value = null;
      notifyListeners();
    }
  }

  // Method to handle incoming commands from clients
  void _handleCommand(String command, Socket socket) {
    try {
      final data = jsonDecode(command);
      
      if (socket == _pendingSocket) {
        if (data['op'] == 'auth' && data['token'] == _pairingService.pairingToken) {
          debugPrint('Auto-accepting connection from authenticated client.');
          acceptConnection();
        } else {
          debugPrint('Invalid auth token, rejecting.');
          rejectConnection();
        }
        return;
      }
      debugPrint('Received command: $command');

      if (data['op'] == 'seek') {
        final pos = data['args']?['position'];
        if (pos != null) {
          _mediaPoller.seek((pos as num).toInt());
        }
        return;
      }

      if (data['op'] == 'music_controls') {
        final action = data['action'];
        if (action != null) {
          _mediaPoller.control(action);
        }
        return;
      }
      return;
    } catch (_) {
      // Not JSON or plain string command
    }

    if (command == "PING") {
      _sendRaw("PONG");
    } else if (command == "PLAY") {
      debugPrint("Play command received");
    } else if (command == "PAUSE") {
      debugPrint("Pause command received");
    } else if (command == "NEXT") {
      debugPrint("Next command received");
    } else if (command == "PREV") {
      debugPrint("Prev command received");
    } else {
      debugPrint("Unknown command: $command");
    }
  }

  // Method to stop the server
  void stopServer() {
    _handleDisconnect();
    _server?.close();
    _httpServer?.stop();
    connectionStatus.value = false;
  }

  // Kill the server and close
  void _handleDisconnect() {
    _mediaPoller.dispose();
    _batteryMonitorServiceLinux.dispose();

    _client?.destroy();
    _client = null;
    _buffer.clear();
    connectedClients.value = 0;
    notifyListeners();
  }

}


