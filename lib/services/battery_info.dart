import 'dart:async';
import 'dart:io';

// --------------------------------     For Linux     -------------------------------------------------
class BatteryMonitorServiceLinux{
  int? _lastLevel;
  bool? _lastCharging;

  StreamSubscription? _subscription;
  final String _batPath = '/sys/class/power_supply/BAT0';

  void start(void Function(String op, String action, Map<String, dynamic> args) onSend) {
    // send at the connection start

    onSend('battery_info', '', {
      'level': _readBattery()?.level,
      'status': _readBattery()?.isCharging,
    });

    _subscription = Stream.periodic(const Duration(seconds: 2), (_) => _readBattery())
        .listen((data) {
      if (data == null) return;

      // Dirty Cache Check
      if (data.level != _lastLevel || data.isCharging != _lastCharging) {
        _lastLevel = data.level;
        _lastCharging = data.isCharging;

        onSend('battery_info', '', {
          'level': data.level,
          'status': data.isCharging,
          'device': Platform.localHostname, 
        });
      }
    });
  }

  void dispose() {
    _subscription?.cancel(); 
    _subscription = null;   
  }

  ({int level, bool isCharging})? _readBattery() {
    try {
      final capacityFile = File('$_batPath/capacity');
      final statusFile = File('$_batPath/status');

      final level = int.tryParse(capacityFile.readAsStringSync().trim()) ?? 0;
      final status = statusFile.readAsStringSync().trim().toLowerCase();

      return (level: level, isCharging: status == 'charging');
    } catch (e) {
      return null;
    }
  }
}