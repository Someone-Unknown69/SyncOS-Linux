import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class SimpleHttpServer {
  HttpServer? _server;
  final int port;
  final String _pairingToken;
  String _currentAlbumArtBase64 = "";

  SimpleHttpServer({required this.port, required String pairingToken}) : _pairingToken = pairingToken;

  void updateAlbumArt(String base64String) {
    _currentAlbumArtBase64 = base64String;
  }

  Future<void> start() async {
    final router = Router();

    router.post('/pair', (Request request) async {
      final payload = await request.readAsString();
      try {
        final data = jsonDecode(payload);
        if (data['token'] == _pairingToken) {
          debugPrint('[HttpServer] Pairing successful');
          return Response.ok(jsonEncode({'status': 'authorized'}), headers: {'Content-Type': 'application/json'});
        } else {
          debugPrint('[HttpServer] Pairing failed: invalid token');
          return Response.forbidden(jsonEncode({'status': 'unauthorized'}), headers: {'Content-Type': 'application/json'});
        }
      } catch (e) {
        return Response.badRequest(body: 'Invalid JSON');
      }
    });

    router.get('/art', (Request request) {
      if (_currentAlbumArtBase64.isNotEmpty) {
        return Response.ok(
          jsonEncode({'albumArt': _currentAlbumArtBase64}), 
          headers: {'Content-Type': 'application/json'}
        );
      }
      return Response.notFound(jsonEncode({'error': 'no art available'}));
    });

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    try {
      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      debugPrint('[HttpServer] Running on port ${_server?.port}');
    } catch (e) {
      debugPrint('[HttpServer] Failed to start HTTP Server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('[HttpServer] Stopped');
  }
}
