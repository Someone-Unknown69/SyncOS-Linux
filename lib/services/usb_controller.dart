import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

class ControllerService {
  static final ControllerService _instance = ControllerService._internal();
  factory ControllerService() => _instance;
  ControllerService._internal();

  final LinuxDriver _driver = LinuxDriver();
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _driver.init();
    _initialized = true;
  }

  void keyPress(String action, String keyName) {
    if (!_initialized) init();
    final keyCode = LinuxDriver.keyMap[keyName];

    if(keyCode != null) {
      if(action == 'up') {
        _driver.keyPressUp(keyCode);
      } else if(action == 'down') {
        _driver.keyPressDown(keyCode);
      } else {
        debugPrint("Invalid key action");
      }
    } else {
      debugPrint("Unknown key: $keyName");
    }
  }

  void dispose() {
    if (_initialized) {
      _driver.dispose();
      _initialized = false;
    }
  }
}

// ----------------------------------------      Linux     ---------------------------------------------
// Following this is the code for simulating keypresses by writing the structs in /dev/uinput
// It writers the key struct 2 times (pressed and released) 

// C input struct for 'input_event'
sealed class InputEvent extends Struct {
  @Int64() external int tvSec; // Timestamp (Seconds)
  @Int64() external int tvUsec; // Timestamp (Microseconds)
  @Uint16() external int type; // Type : mouse or keyboard or etc (constants defined below)
  @Uint16() external int code; // The key (e.g... J is 36)
  @Int32() external int value; // 1 : Pressed, 0 : Released
}

sealed class UInputUserSetup extends Struct {
  @Uint16() external int idBus; // 0x03 for USB
  @Uint16() external int idVendor;  // Fake Manufacturer ID
  @Uint16() external int idProduct; // Fake Product ID
  @Uint16() external int idVersion; // Version number
  @Array(80) external Array<Uint8> name; // The name "SyncOS Keyboard"
  @Uint32() external int ffEffectsMax;   // Force feedback (0 for us rn)
}


class LinuxDriver {
  late int fd; // File Descriptor
  final libc = DynamicLibrary.open('libc.so.6'); // linux C library

  // Kernel Constants 
  static const int EV_KEY = 0x01;      // for keyboard
  static const int EV_SYN = 0x00;
  static const int SYN_REPORT = 0x00;

  // Key Map
  static Map<String, int> keyMap = {
    'CROSS' : 37,
    'SQUARE' : 36,
    'TRIANGLE' : 23,
    'CIRCLE' : 38,
    'UP' : 17,
    'DOWN' : 31,
    'LEFT' : 30,
    'RIGHT' : 32,
    'SELECT' : 14,
    'START' : 28,
    'L1' : 16,
    'L2' : 2,
    'R1' : 18,
    'R2': 4,
    // will add more keys
  };

  // Name of our virtual input device
  final List<int> nameStr = "Your-Mom".codeUnits;

  // C functions needed
  late final _open = libc.lookupFunction<Int32 Function(Pointer<Utf8>, Int32), int Function(Pointer<Utf8>, int)>('open');
  late final _write = libc.lookupFunction<IntPtr Function(Int32, Pointer<Void>, IntPtr), int Function(int, Pointer<Void>, int)>('write');
  late final _ioctl = libc.lookupFunction<Int32 Function(Int32, Uint64, IntPtr), int Function(int, int, int)>('ioctl');
  late final _close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  void init() {
    fd = _open('/dev/uinput'.toNativeUtf8(), 6); // O_WRONLY (2) | O_NONBLOCK (4)
    if (fd < 0) {
      debugPrint("Error: Could not open /dev/uinput. Do you have root permissions?");
      return;
    }

    // Inform the kernel about virtual keyboard
    _ioctl(fd, 0x40045564, 0x01); // UI_SET_EVBIT -> EV_KEY

    // Register all keys in the keyMap
    for (var keyCode in keyMap.values) {
      _ioctl(fd, 0x40045565, keyCode); // UI_SET_KEYBIT
    }

    using((Arena arena) {
      final Pointer<UInputUserSetup> setup = arena<UInputUserSetup>();
      setup.ref.idBus = 0x03; // For USB

      final Pointer<Uint8> nameBuffer = setup.cast<Uint8>() + 8;

      // copy the name to destination
      for (int i = 0; i < nameStr.length && i < 79; i++) {
        nameBuffer[i] = nameStr[i];
      }
      nameBuffer[nameStr.length < 80 ? nameStr.length : 79] = 0; // Null terminator

      // 0x405c5503 is UI_DEV_SETUP for 64-bit systems
      _ioctl(fd, 0x405c5503, setup.address);
      _ioctl(fd, 0x5501, 0); // UI_DEV_CREATE
      debugPrint("Virtual Keyboard created successfully.");
    });
  }

  void keyPressUp(int keyCode) {
    if (fd < 0) return;

    using((Arena arena) {
      final event = arena<InputEvent>();
      event.ref.type = EV_KEY; // MUST RESET TO EV_KEY
      event.ref.code = keyCode;
      event.ref.value = 0; // Released
      _write(fd, event.cast(), sizeOf<InputEvent>());

      // Sync
      event.ref.type = EV_SYN;
      event.ref.code = SYN_REPORT;
      event.ref.value = 0;
      _write(fd, event.cast(), sizeOf<InputEvent>());
    });
  }

  void keyPressDown(int keyCode) {
    if(fd < 0) return;

    using((Arena arena) {
      final event = arena<InputEvent>();
      event.ref.type = EV_KEY;
      event.ref.code = keyCode;
      event.ref.value = 1; // Pressed
      _write(fd, event.cast(), sizeOf<InputEvent>());

      // Sync
      event.ref.type = EV_SYN;
      event.ref.code = SYN_REPORT;
      event.ref.value = 0;
      _write(fd, event.cast(), sizeOf<InputEvent>());
    });
  }

  void dispose() {
    debugPrint("Virtual keyboard disposed successfully");
    _ioctl(fd, 0x5502, 0); // UI_DEV_DESTROY: Tell kernel to remove the device
    _close(fd);            // Close the file handle
  }
}


// -----------------------------------------    Windows    -----------------------------------------------