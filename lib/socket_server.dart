import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'services/handle_methods.dart';


// ---------------------------      Request send template     --------------------------------------------
// This is the template for any request sent to the other device
Map<String, dynamic> createRequest({
required String op,
required String action,
Map<String, dynamic>? args,
}) {
  return {
    "op": op,           // Operation type                    
    "action": action,   // action to be taken
    "args": args,        // arguments  
    "id": DateTime.now().millisecondsSinceEpoch, // Sequence number
  };
}



// --------------------------------    Socket Class      -------------------------------------------------
 
class SocketServer extends ChangeNotifier{
  // ------------------------------    Class Variables    ------------------------------------------------
  ServerSocket? _server;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final _messageController = StreamController<String>.broadcast();
  Socket? _client;
  Timer? _statusTimer;
  Socket? _pendingSocket;

  // Defining where to connect the socket
  SocketServer();
  
  // ----------------------------  Client  Device Information    ---------------------------------
  final ValueNotifier<int> batteryLevel = ValueNotifier(0);
  final ValueNotifier<int> latency = ValueNotifier<int>(0); // Not applicable for server
  final ValueNotifier<String>  deviceName = ValueNotifier<String>(Platform.localHostname);
  final ValueNotifier<bool> isCharging = ValueNotifier<bool>(false); // Static
  final ValueNotifier<int> connectedClients = ValueNotifier<int>(0);
  final ValueNotifier<String?> pendingClientIP = ValueNotifier<String?>(null);

  // ---------------------------------    Getters    -------------------------------------------- 
  Stream<String> get messageStream => _messageController.stream;

  // ---------------------------    Data to send Periodicallyy    --------------------------------
  bool _isSending = false; // Semaphore
  
  final SystemDataService _serviceSystemInfo = SystemDataService();

  Future<void> _sendStatusToAllClients() async {
    if (_isSending) return;

    // debugPrint("Sending periodic status update");
    _isSending = true;

    try {
      // Fetch dynamic status (Identity + Battery)
      final data = await _serviceSystemInfo.getFullDeviceStatus();
      
      // Update local notifiers for UI
      batteryLevel.value = data['battery'];
      isCharging.value = data['isCharging'];
      deviceName.value = data['name'];


      notifyListeners();
      
      // Encode the request to send
      final info = jsonEncode(createRequest(op: "sys_info", action: "get", args: data));
      
      // Send to the client
      if (_client != null) {
        try {
          _client!.write("$info\n");
        } catch (e) {
          debugPrint("Failed to send to client: $e");
        }
      }
      
      debugPrint("Status sent to client: ${data['name']} - ${data['battery']} - ${data['isCharging']}");
    } catch (e) {
      debugPrint("Failed to send status to all: $e");
    } finally {
      _isSending = false;
    }
  }


  // --------------------------------     Methods    --------------------------------------------

  // Asynchronous method to start server and listen for connections
  Future<void> startServer(int port) async{
    try {
      debugPrint('Starting server on port $port...');
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

      connectionStatus.value = true;
      debugPrint('Server started successfully');

      _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _sendStatusToAllClients();
      });

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

  // Setting up the socket listner to get client's data
  void _setupSocketListeners(Socket socket) {
    socket.cast<List<int>>()
    .transform(utf8.decoder)
    .listen(
      (String data) {
        _handleCommand(data.trim(), socket);
      },
      onError: (e){
        debugPrint('Error from client: $e');
      },
      onDone: () {
        debugPrint('Client disconnected: ${socket.remoteAddress.address}:${socket.remotePort}');
        _client = null;
        connectedClients.value = 0;
        notifyListeners();
      },
    );
  }

  void acceptConnection() {
    if (_pendingSocket != null) {
      try {
        _pendingSocket!.write('ACCEPTED\n');
        _pendingSocket!.flush();
      } catch (e) {
        debugPrint('Failed to send accept response: $e');
      }
      _client = _pendingSocket;
      connectedClients.value = 1;
      _setupSocketListeners(_pendingSocket!);
      _pendingSocket = null;
      pendingClientIP.value = null;
      notifyListeners();
    }
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
    _statusTimer?.cancel();
    _statusTimer = null;

    if (_pendingSocket != null) {
      _pendingSocket!.close();
      _pendingSocket = null;
      pendingClientIP.value = null;
    }

    if (_client != null) {
      _client!.destroy();
      _client = null;
      connectedClients.value = 0;
    }

    _server?.close();
    _server = null;
    connectionStatus.value = false;
    debugPrint("Server stopped.");
  }


  // Method to send data to the client
  void send(String str) {
    if (_client != null) {
      try {
        _client!.write("$str\n");
      } catch (e) {
        debugPrint('Error sending to client: $e');
      }
    }
  }

}


