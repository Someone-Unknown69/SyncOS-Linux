import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/media/data/mpris_service.dart';
import 'package:laptop_controller/core/media/domain/i_media_notification.dart';

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