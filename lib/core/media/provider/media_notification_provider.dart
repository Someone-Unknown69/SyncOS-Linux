// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/media/data/mpris_service.dart';
import 'package:syncos_linux/core/media/domain/i_media_notification.dart';
import 'package:syncos_linux/features/media/provider/remote_media_provider.dart';

final mediaNotificationProvider = Provider<IMediaNotification>((ref) {
  final client = DBusClient.session();
  final remoteMediaService = ref.watch(remoteMediaServiceProvider);
  final service = MprisService(client, remoteMediaService);

  ref.onDispose(() async {
    service.stop();
    client.close();
  });

  return service;
});
