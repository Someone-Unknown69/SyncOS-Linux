import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/features/gamepad/domain/i_controller_service.dart';
import 'package:laptop_controller/features/media/data/local_media_sender.dart';
import 'package:laptop_controller/features/media/provider/remote_media_state.dart';
import 'package:laptop_controller/features/notification/domain/i_remote_notification_service.dart';
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
  final IControllerService _controllerService;
  final IRemoteNotificationService _remoteNotificationService;

  StreamSubscription<String>? _rawMessageSubscription;
  bool _isStarted = false;

  CommandDispatcher(
    this.ref,
    this._connectionManager, 
    this._mediaSender,
    this._fileTransferService,
    this._controllerService,
    this._remoteNotificationService,
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
            _mediaSender.handleControlCommand(args);
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
        case 'controller':
          if(action == 'start') {
            _controllerService.init();
          } else if (action == 'stop') {
            _controllerService.dispose();
          } else if (action == 'left_analog') {
            _controllerService.updateLeftStick(args);
          } else if (action == 'right_analog') {
            _controllerService.updateRightStick(args['x'], args['y']);
          } else if (action == 'triggers') {
            _controllerService.updateTriggers(args['l2'], args['r2']);
          } else if (action == 'dpad') {
            _controllerService.updateDpad(args['x'], args['y']);
          } else {
            _controllerService.keyPress(action, args['button']);
          }
        case 'notification':
          if(action == 'receive') {
            _remoteNotificationService.saveNotification(args);
          }
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
