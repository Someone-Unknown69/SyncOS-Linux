// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/features/battery/provider/remote_battery_state.dart';
import '../../../theme/app_theme.dart';


class BatteryCard extends ConsumerWidget {
  const BatteryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),

      child: Row(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(batteryProvider);

              final batteryColor = state.isCharging
                ? Colors.blueAccent
                : (state.level < 0.2 ? Colors.redAccent : const Color(0xFF4CAF50));

              return Row(
                children: [
                  _buildIconWell(
                    child: _VerticalBattery(level: state.level, color: batteryColor),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Battery", style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
                      Text("${(state.level).toInt()}%",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      if (state.isCharging)
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
              );
            }
          )
        ],
      ),
    );
  }
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

class _VerticalBattery extends StatelessWidget {
  final int level;
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
              height: (24 * (level / 100)).toDouble(),
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