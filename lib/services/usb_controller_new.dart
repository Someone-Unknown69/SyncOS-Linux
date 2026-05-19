import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

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

  static const Set<String> validButtons = {
    'CROSS', 'CIRCLE', 'SQUARE', 'TRIANGLE',
    'L1', 'R1', 'L2', 'R2',
    'SELECT', 'START'
  };

  static const Set<String> validDirections = {
    'UP', 'DOWN', 'LEFT', 'RIGHT'
  };

  void handleInput(String action, String keyName) {
    if (!_initialized) init();

    // Standardize string input to match our driver expectations
    final String keyUpper = keyName.toUpperCase();
    final String actionLower = action.toLowerCase();
    final bool isPressed = (actionLower == 'down');

    // Regular face/shoulder button
    if (validButtons.contains(keyUpper)) {
      _driver.updateButton(keyUpper, isPressed);
    } 
    // D-Pad movement
    else if (validDirections.contains(keyUpper)) {
      if (isPressed) {
        // Send the active direction
        _driver.updateDpad(keyUpper);
      } else {
        // On release, reset the Hat switch to neutral center
        _driver.updateDpad('CENTER');
      }
    } 
    else {
      debugPrint("[Gamepad] Unknown or unmapped hardware key: $keyName");
    }
  }

  void dispose() {
    if (_initialized) {
      _driver.dispose();
      _initialized = false;
    }
  }
}

// ----------------------------------------      Linux     --------------------------------------
// The previous implementation can be seen in usb_controller_old.dart (kept it as a souviner)

// Instead of configuring raw key bitmasks on the fly, we feed the kernel a pre-compiled HID Report Descriptor. 
// This descriptor is a standard binary blueprint that hardware manufacturers code into physical USB or Bluetooth controllers. 
// It explicitly outlines every button, stick, and D-pad layout on the device before any inputs are even sent. 

// UHID Action Constants from <linux/uhid.h>
const int UHID_CREATE2 = 0x0b;
const int UHID_INPUT2 = 0x0d;

/// Structural layout representing the registration specifications of the device
/// We are spoofing a X-Box 360 controller here
sealed class UhidCreate2Req extends Struct {
  @Array(128) external Array<Uint8> name;     // Device string identification tag
  @Array(64)  external Array<Uint8> phys;     // Physical path trace
  @Array(64)  external Array<Uint8> uniq;     // Unique serial signature
  @Uint16()    external int rdSize;            // Exact length of the HID Descriptor array
  @Uint16()    external int bus;               // Bus transmission standard (0x03 = USB)
  @Uint32()    external int vendor;            // Spoofed Manufacturer Vendor ID
  @Uint32()    external int product;           // Spoofed Hardware Product ID
  @Uint32()    external int version;           // Firmware version
  @Uint32()    external int country;           // Localization country bitmask
  @Array(4096) external Array<Uint8> rdData;   // The raw byte array holding the descriptor rules
}

/// Structural layout used to pass runtime button state updates
sealed class UhidInput2Req extends Struct {
  @Uint16()    external int size;              // Length of your state report packet (3 bytes)
  @Array(4096) external Array<Uint8> data;     // The byte array holding active button bits
}

/// The main wrapper container block injected directly into the system file descriptor
sealed class UhidEvent extends Struct {
  @Uint32() external int type;                 // Command tracking mode flag (UHID_CREATE2 / UHID_INPUT2)
  @Array(4352) external Array<Uint8> payload;  // Union buffer space safely wrapping payload chunks
}

/// Fixed layout specifications parsed by the kernel's Human Interface Device compiler layer.
final List<int> gamepadHidReportDescriptor = [
  0x05, 0x01,        // USAGE_PAGE (Generic Desktop)
  0x09, 0x05,        // USAGE (Gamepad)
  0xa1, 0x01,        // COLLECTION (Application)
  
  // 16 Sequential Binary Digital Buttons (Cross, Circle, Triggers, System Pins)
  0x05, 0x09,        //   USAGE_PAGE (Button)
  0x19, 0x01,        //   USAGE_MINIMUM (Button 1)
  0x29, 0x10,        //   USAGE_MAXIMUM (Button 16)
  0x15, 0x00,        //   LOGICAL_MINIMUM (0)
  0x25, 0x01,        //   LOGICAL_MAXIMUM (1)
  0x75, 0x01,        //   REPORT_SIZE (1 bit per button)
  0x95, 0x10,        //   REPORT_COUNT (16 buttons total = 2 bytes)
  0x81, 0x02,        //   INPUT (Data, Variable, Absolute flags)
  
  // Directional D-Pad (Configured via a Clockwise Angular Hat Switch)
  0x05, 0x01,        //   USAGE_PAGE (Generic Desktop)
  0x09, 0x39,        //   USAGE (Hat switch mapping track)
  0x15, 0x00,        //   LOGICAL_MINIMUM (0 = Up)
  0x25, 0x07,        //   LOGICAL_MAXIMUM (7 = Up-Left)
  0x35, 0x00,        //   PHYSICAL_MINIMUM (0)
  0x46, 0x3b, 0x01,  //   PHYSICAL_MAXIMUM (315 degrees boundary)
  0x65, 0x14,        //   UNIT (Rotational Angular Position notation)
  0x75, 0x04,        //   REPORT_SIZE (4 bits allocation size)
  0x95, 0x01,        //   REPORT_COUNT (1 single Hat interface)
  0x81, 0x42,        //   INPUT (Data, Variable, Absolute, Null State when idle)
  
  // Alignment Padding Block
  // till now we have consumed 20 bits (16 buttons + 4 D-pad bits). We add 4 bits of padding to round it to 24 bits (exactly 3 bytes).
  0x95, 0x01,        //   REPORT_COUNT (1 structure chunk)
  0x75, 0x04,        //   REPORT_SIZE (4 bits structure width padding)
  0x81, 0x03,        //   INPUT (Constant structural alignment spacer)

  0xc0               // END_COLLECTION
];


class LinuxDriver {
  late int fd;
  final libc = DynamicLibrary.open('libc.so.6');

  // Local state tracking memory arrays
  int _buttonStateBitmask = 0; 
  int _dpadStateValue = 8; // Default value 8 indicates the D-pad is centered/at rest

  // C bindings mapping signatures
  late final _open = libc.lookupFunction<Int32 Function(Pointer<Utf8>, Int32), int Function(Pointer<Utf8>, int)>('open');
  late final _write = libc.lookupFunction<IntPtr Function(Int32, Pointer<Void>, IntPtr), int Function(int, Pointer<Void>, int)>('write');
  late final _close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>('close');


  // Bit index offsets assigned to matching button inputs
  static const Map<String, int> buttonBits = {
    'CROSS': 0, 'CIRCLE': 1, 'SQUARE': 2, 'TRIANGLE': 3,
    'L1': 4, 'R1': 5, 'L2': 6, 'R2': 7,
    'SELECT': 8, 'START': 9
  };

  // Angular mapping values for the D-pad (0=Up, 2=Right, 4=Down, 6=Left, 8=Centered)
  static const Map<String, int> dpadValues = {
    'UP': 0, 'RIGHT': 2, 'DOWN': 4, 'LEFT': 6, 'CENTER': 8
  };


  void init() {
    // Open the user space HID communications channel node

    fd = _open('/dev/uhid'.toNativeUtf8(), 2); // O_RDWR (Mode 2)
    
    if (fd < 0) {
      debugPrint("[Gamepad] Access to /dev/uhid blocked. Deploying the automated privilege elevation rule tool");
      _requestOneTimeUdevSetup();
      return;
    }

    using((Arena arena) {
      final Pointer<UhidEvent> event = arena<UhidEvent>();
      event.ref.type = UHID_CREATE2;

      // Extract pointer index offset to target the inner payload structure safely
      final Pointer<UhidCreate2Req> req = event.cast<Uint8>().asciiOffset(4).cast<UhidCreate2Req>();
      
      // Hardware Hardware Spoofer Metadata
      req.ref.bus = 0x03;       // BUS_USB
      req.ref.vendor = 0x045E;  // Officially registers as a Microslop asset
      req.ref.product = 0x028E; // Officially registers as an Xbox 360 controller hardware configuration
      req.ref.version = 1;
      req.ref.rdSize = gamepadHidReportDescriptor.length;

      // Map device identity name string
      final List<int> nameBytes = "SyncOS Xbox Component".codeUnits;
      for (int i = 0; i < nameBytes.length && i < 127; i++) {
        req.ref.name[i] = nameBytes[i];
      }

      // Populate hardware blueprint bytes inside the descriptor data segment
      for (int i = 0; i < gamepadHidReportDescriptor.length; i++) {
        req.ref.rdData[i] = gamepadHidReportDescriptor[i];
      }

      // Dispatch registration parameters frame structure block down to kernel pipeline layers
      _write(fd, event.cast(), 512); 
      debugPrint("[Gamepad] UHID Controller successfully registered");
    });
  }

  /// Toggle button status frames and update the kernel pipeline layers
  void updateButton(String buttonName, bool isPressed) {
    final bitOffset = buttonBits[buttonName];
    if (bitOffset == null || fd < 0) return;

    if (isPressed) {
      _buttonStateBitmask |= (1 << bitOffset); // Set target bit high
    } else {
      _buttonStateBitmask &= ~(1 << bitOffset); // Pull target bit low
    }
    _sendInputReport();
  }

  /// Alter active digital D-pad positional trajectory routes
  void updateDpad(String direction) {
    if (fd < 0) return;
    _dpadStateValue = dpadValues[direction] ?? 8;
    _sendInputReport();
  }

  /// Package the compact 3-byte input status layout profile block
  void _sendInputReport() {
    using((Arena arena) {
      final Pointer<UhidEvent> event = arena<UhidEvent>();
      event.ref.type = UHID_INPUT2;

      final Pointer<UhidInput2Req> req = event.cast<Uint8>().asciiOffset(4).cast<UhidInput2Req>();
      req.ref.size = 3; // Exactly 3 bytes matching our design specification

      // Byte 0: Digital Buttons Group A (Bits 1 to 8)
      req.ref.data[0] = _buttonStateBitmask & 0xFF;
      // Byte 1: Digital Buttons Group B (Bits 9 to 16)
      req.ref.data[1] = (_buttonStateBitmask >> 8) & 0xFF;
      // Byte 2: Lower 4 bits hold the D-pad angular value, upper 4 bits are empty padding
      req.ref.data[2] = _dpadStateValue & 0x0F;

      _write(fd, event.cast(), 16); 
    });
  }


  /// Triggered automatically if your user tries running the application without root execution privileges
  void _requestOneTimeUdevSetup() {
    Process.run('pkexec', [
      'sh', '-c', 
      'echo "KERNEL==\"uhid\", TAG+=\"uaccess\"" > /etc/udev/rules.d/99-syncos-uhid.rules && udevadm control --reload-rules && udevadm trigger'
    ]).then((ProcessResult result) {
      if (result.exitCode == 0) {
        debugPrint("[Gamepad] Udev configuration rules fixed successfully. Restart the application to mount device.");
      } else {
        debugPrint("[Gamepad] Error: Privilege authorization rejected by user.");
      }
    });
  }


  void dispose() {
    if (fd >= 0) _close(fd);
  }

}

extension on Pointer<Uint8> {
  Pointer<Uint8> asciiOffset(int offset) => Pointer<Uint8>.fromAddress(address + offset);
}