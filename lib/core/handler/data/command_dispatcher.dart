import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/features/media/data/local_media_sender.dart';
import 'package:laptop_controller/features/media/provider/remote_media_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/features/device_info/provider/remote_device_info_state.dart';
import 'package:laptop_controller/features/battery/provider/remote_battery_state.dart';
import 'package:laptop_controller/features/file_transfer/data/file_transfer_service.dart';

class CommandDispatcher {
  final Ref ref;
  final IConnectionManager _connectionManager;
  final LocalMediaSender _mediaSender;
  final FileTransferService _fileTransferService;

  StreamSubscription<String>? _rawMessageSubscription;
  bool _isStarted = false;

  CommandDispatcher(
    this.ref,
    this._connectionManager, 
    this._mediaSender,
    this._fileTransferService,
  );

  void start() {
    if (_isStarted) return;
    _isStarted = true;

    _rawMessageSubscription = _connectionManager.rawMessageStream.listen((rawMessage) {
      final Map<String, dynamic> data = jsonDecode(rawMessage);
      final String operation = data['op'];
      final String action = data['action'];
      final Map<String, dynamic> args = data['args'];

      debugPrint('[Dispatcher] : Recieved $data');

      switch(operation) {
        case 'music':
          if(action == 'update_metadata') {
            ref.read(musicProvider.notifier).updateMetadata(args);
          } else if (action == 'control') {
            _mediaSender.sendControlCommand(args);
          }
          break;
        case 'battery_info':
          ref.read(batteryProvider.notifier).update(
            args['level'] ?? 0, 
            args['status'] ?? false
          );
          break;
        case 'device_info':
          ref.read(deviceInfoProvider.notifier).update(args['name']);
          break;
        case 'file_transfer':
          if(action == 'receive') {
            _fileTransferService.recieveFile(args);
          } else if(action == 'send') {
            // will add ability to send file requests in future 
          } 
          break;
      }
    });
  }

  void stop() {
    _rawMessageSubscription?.cancel();
    _rawMessageSubscription = null;
    _isStarted = false;
  }

  void dispose() {
    stop();
  }
}
