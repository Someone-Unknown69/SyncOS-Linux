// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/config/app_router.dart';
import 'package:syncos_linux/core/config/app_routes.dart';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/core/storage/provider/storage_service_provider.dart';
import 'package:syncos_linux/pages/components/base_page.dart';
import 'package:syncos_linux/pages/components/popup_dialog.dart';
import 'package:syncos_linux/pages/components/settings_tile.dart';
import 'package:syncos_linux/pages/settings/widgets/color_picker.dart';
import 'package:syncos_linux/pages/settings/widgets/connection_details.dart';
import 'package:syncos_linux/theme/provider/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  @override
  Widget build(BuildContext context){
    final theme = Theme.of(context);

    return BasePage(
      title: 'Settings', 
      showBackButton: false,
      children: [
        buildSectionHeader(context, 'Connection Details'),
        ConnectionDetailsCard(),

        buildSettingsTile(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Unpair Device',
          subtitle:'Connect with new device',
          onTap: () async {
            final storage = ref.read(storageServiceProvider);
            final isPaired = await storage.isPaired;
            final asyncStatus = ref.watch(connectionStatusProvider);

            if (!context.mounted) return;

            if (isPaired) {
              await showAppPopupDialog(
                context,
                title: 'Unpair Device',
                subtitle: 
                  (asyncStatus.value == ConnectionStatus.connected) ? 
                  "This will remove the client and it's connection data" :
                  "Device is disconnected from client, Note that If you are unpairing now then you have to unpair client explicitly" ,
                
                primaryButtonLabel: 'Unpair',
                secondaryButtonLabel: 'Cancel',
                onPrimaryPressed: () async {
                  await ref.read(connectionManagerProvider).unpair();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device unpaired successfully.'),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                },
              );
            } else {
              // This shall not be case anytime, but if it is then check the code 
              // There must be something fishy
              AppRouter.pushRoute(context, AppRoutes.pairingScreen);
            }
          },
        ),


        buildSectionHeader(context, 'Preferences'),
        buildSettingsTile(
          icon: Icons.dark_mode_rounded,
          title: 'Theme Mode',
          subtitle: 'Switch between light and dark mode',
          trailing: Switch(
            value: theme.brightness == Brightness.dark,
            onChanged: (bool value) {
              ref.read(themeProvider.notifier).updateThemeMode(
                value ? ThemeMode.dark : ThemeMode.light
              );
            },
          ),
        ),

        buildSettingsTile(
          icon: Icons.color_lens_rounded,
          title: 'App Theme',
          subtitle: 'Select your preferred accent color',
          onTap: () => _showColorPicker(context, ref),
        ),

        buildSectionHeader(context, "Info"),
        buildSettingsTile(
          icon: Icons.info_outline, 
          title: "SyncOS Desktop",
          subtitle: 'Version 1.0.0',
        ),
      ]
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: HorizontalColorPicker(
          selectedColor: ref.watch(themeProvider).seedColor,
          onColorSelected: (color) {
            ref.read(themeProvider.notifier).updateSeedColor(color);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}