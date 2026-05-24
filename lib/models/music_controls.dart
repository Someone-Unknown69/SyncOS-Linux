import '../services/socket_server.dart';

class MusicControls {
  final client = SocketServer.instance;

  void playpause() {
    client.send('music', 'control', {'method': 'play_pause'});
  }

  void next() {
    client.send('music', 'control', {'method': 'next'});
  }

  void previous() {
    client.send('music', 'control', {'method': 'previous'});
  }

  void seek(int position) {
    client.send(
      "music", 
      "control", 
      {
        "method" : 'seek',
        "position": position,
      }
    );
  }
}