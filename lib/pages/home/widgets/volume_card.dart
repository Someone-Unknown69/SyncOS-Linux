import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';

class VolumeCard extends ConsumerWidget {
  const VolumeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dummy state for now , change this when migrating to a Provider/Notifier
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const double dummyVolume = 0.7;

    return Container(
      padding: const EdgeInsets.all(AppTheme.padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
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
                Text(
                  "${(dummyVolume * 100).toInt()}%",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
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
                      value: dummyVolume,
                      onChanged: (_) {}, // Dummy callback remains interactive visually but does nothing
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}