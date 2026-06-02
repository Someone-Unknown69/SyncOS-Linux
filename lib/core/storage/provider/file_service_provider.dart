import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/file_service_impl.dart';
import '../domain/i_file_service.dart';

final fileServiceProvider = Provider<IFileService>((ref) {
  return FileServiceImpl();
});