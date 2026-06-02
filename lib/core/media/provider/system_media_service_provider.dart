import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/media/data/mpris_service.dart';
import 'package:laptop_controller/core/media/domain/i_system_media_service.dart';

final systemMediaServiceProvider = FutureProvider<ISystemMediaService>((ref) async {
  final client = DBusClient.session();
  final service = MprisService(client);

  await service.init();

  ref.onDispose(() async {
    await service.reset();
    client.close();
  });

  return service;
});