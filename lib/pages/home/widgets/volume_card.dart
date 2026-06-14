// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

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
            child: Icon(Icons.volume_up, color: colorScheme.onSurface, size: 24),
            colorScheme : colorScheme,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Volume", style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
                Text(
                  "${(dummyVolume * 100).toInt()}%",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
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

  Widget _buildIconWell({required Widget child, ColorScheme? colorScheme}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colorScheme!.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}