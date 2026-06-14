// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/media/data/mpris_service.dart';
import 'package:syncos_linux/core/media/domain/i_media_notification.dart';

final mediaNotificationProvider = FutureProvider<IMediaNotification>((ref) async {
  final client = DBusClient.session();
  final service = MprisService(client, ref);

  await service.init();

  ref.onDispose(() async {
    service.reset();
    client.close();
  });

  return service;
});