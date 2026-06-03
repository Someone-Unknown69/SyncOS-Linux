import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/features/pairing/data/pairing_service.dart';
import 'package:laptop_controller/features/pairing/domain/i_pairing_service.dart';

final pairingProvider = Provider<IPairingService> ((ref) {
  final storage = ref.watch(storageServiceProvider);
  return PairingService(storage);
});

