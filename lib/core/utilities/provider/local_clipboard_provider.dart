import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/utilities/data/linux_clipboard.dart';
import 'package:laptop_controller/core/utilities/domain/i_local_clipboard.dart';

final localClipboardInfoProvider = Provider<ILocalClipboard>((ref) {
  return LinuxClipboard();
});