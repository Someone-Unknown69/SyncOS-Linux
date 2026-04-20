import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'services/music.dart';
import 'services/battery_info.dart';


// --------------------------------    Socket Class      -------------------------------------------------
 
class SocketServer extends ChangeNotifier{
  // ------------------------------    Class Variables    ------------------------------------------------
  ServerSocket? _server;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final _messageController = StreamController<String>.broadcast();
  Socket? _client;
  Socket? _pendingSocket;

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
  

  // ----------------------------  Client  Device Information    ---------------------------------
  final ValueNotifier<String>  deviceName = ValueNotifier<String>(Platform.localHostname);
  final ValueNotifier<int> connectedClients = ValueNotifier<int>(0);
  final ValueNotifier<String?> pendingClientIP = ValueNotifier<String?>(null);


  // ---------------------------------    Getters    -------------------------------------------- 
  Stream<String> get messageStream => _messageController.stream;


  // --------------------------------     Methods    --------------------------------------------
  // Asynchronous method to start server and listen for connections
  Future<void> startServer(int port) async{
    try {
      debugPrint('Starting server on port $port...');
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

        notifyListeners();
      });

    } catch (e) {
      connectionStatus.value = false;
      debugPrint('Error while starting server: $e');
    }
  }

  // Method to send requests to client
  void send(String op, Map<String, dynamic> args) {
    if (_client == null) return;

    try {
      final request = {
        "op": op,
        "args": args,
        "id": DateTime.now().millisecondsSinceEpoch,
      };

      _client!.write('${jsonEncode(request)}\n');
      _client!.flush();
    } catch (e) {
      debugPrint('Send error: $e');
      _handleDisconnect();
    }
  }

  // Setting up the socket listner to get client's requests
  void _setupSocketListeners(Socket socket) {
    socket.cast<List<int>>().transform(utf8.decoder).listen(
      (String data) => _handleCommand(data.trim(), socket),
      onDone: () => _handleDisconnect(),
      onError: (e) => _handleDisconnect(),
    );
  }

 // Change return type to Future<void> and add async
  Future<void> acceptConnection() async { 
    if (_pendingSocket == null) return;

    _client = _pendingSocket;
    _pendingSocket = null;
    pendingClientIP.value = null;
    connectedClients.value = 1;

    try {
      _client!.write('ACCEPTED\n');
      await _client!.flush(); 
    } catch (e) {
      debugPrint('Handshake failed: $e');
    }

    _setupSocketListeners(_client!);
    
    _mediaPoller.start(send);
    _batteryMonitorServiceLinux.start(send); 

    notifyListeners();
  }

  void rejectConnection() {
    if (_pendingSocket != null) {
      try {
        _pendingSocket!.write('REJECTED\n');
        _pendingSocket!.flush();
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
    debugPrint('Received command: $command');
    if (command == "PING") {
      socket.write("PONG\n");
    } else if (command == "PLAY") {
      // Handle play command, e.g., run music player
      debugPrint("Play command received");
      // For example: Process.run('playerctl', ['play']);
    } else if (command == "PAUSE") {
      debugPrint("Pause command received");
    } else if (command == "NEXT") {
      debugPrint("Next command received");
    } else if (command == "PREV") {
      debugPrint("Prev command received");
    } else {
      // Handle other commands, e.g., run terminal command
      debugPrint("Unknown command: $command");
    }
  }

  // Method to stop the server
  void stopServer() {
    _handleDisconnect();
    _server?.close();
    connectionStatus.value = false;
  }

  // Kill the server and close
  void _handleDisconnect() {
    _mediaPoller.dispose();
    _batteryMonitorServiceLinux.dispose();

    _client?.destroy();
    _client = null;
    connectedClients.value = 0;
    notifyListeners();
  }

}

