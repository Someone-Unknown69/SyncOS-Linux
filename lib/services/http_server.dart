import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';

class SimpleHttpServer {
  final int port;
  final String pairingToken;
  String _currentAlbumArtBase64 = "";
  HttpServer? _server;

  SimpleHttpServer({required this.port, required this.pairingToken});

  void updateAlbumArt(String base64) {
    _currentAlbumArtBase64 = base64;
  }

  Future<void> start() async {
    final router = Router();

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
      _server = await io.serve(handler, InternetAddress.anyIPv4, port);
      debugPrint('[HttpServer] Running on port ${_server!.port}');
    } catch (e) {
      debugPrint('[HttpServer] Failed to start: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
