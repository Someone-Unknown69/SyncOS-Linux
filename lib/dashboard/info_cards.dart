import 'package:flutter/material.dart';

/// Battery and Volume telemetry cards 
Widget infoCardsRow({
  required ValueNotifier<double> batteryLevelNotifier,
  required ValueNotifier<bool> isChargingNotifier,
  required ValueNotifier<double> volumeNotifier,
  required ValueChanged<double> onVolumeChanged,
  required BuildContext context,
}) {
  final theme = Theme.of(context);
  final cardBgColor = theme.colorScheme.surfaceContainerLow;

  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- MODULAR BATTERY CARD ---
        Expanded(
          child: _BatteryCard(
            batteryLevelNotifier: batteryLevelNotifier,
            isChargingNotifier: isChargingNotifier,
            cardBgColor: cardBgColor,
          ),
        ),

        const SizedBox(width: 12),

        // --- MODULAR VOLUME CARD ---
        Expanded(
          child: _VolumeCard(
            volumeNotifier: volumeNotifier,
            onVolumeChanged: onVolumeChanged,
            cardBgColor: cardBgColor,
          ),
        ),
      ],
    ),
  );
}

// ==========================================================================
// Bruh the code getting bigger
// ==========================================================================

class _BatteryCard extends StatelessWidget {
  final ValueNotifier<double> batteryLevelNotifier;
  final ValueNotifier<bool> isChargingNotifier;
  final Color cardBgColor;

  const _BatteryCard({
    required this.batteryLevelNotifier,
    required this.isChargingNotifier,
    required this.cardBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: batteryLevelNotifier,
      builder: (context, batteryLevel, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isChargingNotifier,
          builder: (context, isCharging, _) {
            final batteryColor = isCharging
                ? Colors.blueAccent
                : (batteryLevel < 0.2 ? Colors.redAccent : const Color(0xFF4CAF50));

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _buildIconWell(
                    child: _VerticalBattery(level: batteryLevel, color: batteryColor),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Battery", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text("${(batteryLevel * 100).toInt()}%",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (isCharging)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.bolt, size: 14, color: batteryColor),
                              Text("Charging", style: TextStyle(color: batteryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VolumeCard extends StatelessWidget {
  final ValueNotifier<double> volumeNotifier;
  final ValueChanged<double> onVolumeChanged;
  final Color cardBgColor;

  const _VolumeCard({
    required this.volumeNotifier,
    required this.onVolumeChanged,
    required this.cardBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: volumeNotifier,
      builder: (context, volume, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _buildIconWell(
                child: const Icon(Icons.volume_up, color: Colors.white70, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Volume", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text("${(volume * 100).toInt()}%",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF448AFF),
                        inactiveTrackColor: Colors.white10,
                        thumbColor: const Color(0xFF90CAF9),
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Slider(
                          value: volume,
                          onChanged: onVolumeChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildIconWell({required Widget child}) {
  return Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      shape: BoxShape.circle,
    ),
    child: Center(child: child),
  );
}

class _VerticalBattery extends StatelessWidget {
  final double level;
  final Color color;
  const _VerticalBattery({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        Container(
          width: 18,
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 24 * level,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}