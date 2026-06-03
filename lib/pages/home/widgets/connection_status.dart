import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';


final syncedDeviceTextProvider = FutureProvider<String>((ref) async {
  // TODO : Add a way to get username
  return "Synced With : Kartik";
});

class StatusNotConnected extends ConsumerWidget {
  const StatusNotConnected({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // TODO : Redesign this to a beautiful interface

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Device Not Connected",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusConnected extends ConsumerWidget {
  const StatusConnected({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Welcome back !", 
                style: TextStyle(fontSize: 30 ,fontWeight: FontWeight.w600)
              ),

              Row( 
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Ping button 
                  FilledButton.icon(
                    onPressed: () => {},
                    icon: const Icon(Icons.network_ping_rounded),
                    label: const Text("Ping"),
                    style: FilledButton.styleFrom(
                      elevation: 0, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      ),
                      backgroundColor: colorScheme.primary,
                    ),
                  ),

                  SizedBox(width: AppTheme.spacing),

                  // disconnect button
                  FilledButton.icon(
                    onPressed: () async {},
                    icon: const Icon(Icons.power_off),
                    label: const Text("Disconnect"),
                    style: FilledButton.styleFrom(
                      elevation: 0, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: colorScheme.surfaceBright,
                    ),
                  ),
                ],
              )
            ],
          ),

          SizedBox(height: AppTheme.spacing / 2),

          Row(
            mainAxisSize: MainAxisSize.min, // Prevents row from taking too much space
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.greenAccent, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Space between dot and text
              
              Consumer(
                builder: (context, ref, child) {
                  final syncedDeviceAsync = ref.watch(syncedDeviceTextProvider);

                  return syncedDeviceAsync.when(
                    data: (textLine) => Text(
                      textLine,
                      style: const TextStyle(fontSize: 14),
                    ),
                    loading: () => const Text(
                      "Synced With : Loading...",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    error: (err, stack) => const Text(
                      "Synced With : Unknown Device",
                      style: TextStyle(fontSize: 14, color: Colors.redAccent),
                    ),
                  );
                } 
              ),
            ],
          ),
        ],
      ),
    );
  }
}
