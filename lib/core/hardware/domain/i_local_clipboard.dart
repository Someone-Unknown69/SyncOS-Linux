import 'dart:async';

abstract class ILocalClipboard {
  void init();
  Stream<String> get clipboardUpdates;
  void dispose();
}