import 'dart:io';
import 'dart:async';

void main() async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  print('Listening on ${server.port}');
  server.listen((client) {
    try {
      client.add([1, 2, 3]);
      print('Added successfully');
      // What if we add multiple times concurrently?
      Future.wait([
        Future(() => client.add([4, 5])),
        Future(() => client.add([6, 7])),
      ]);
    } catch (e) {
      print('Error: $e');
    }
  });

  final client = await Socket.connect('127.0.0.1', server.port);
  client.listen((data) {
    print('Client received: $data');
  });
  
  await Future.delayed(Duration(seconds: 2));
  exit(0);
}
