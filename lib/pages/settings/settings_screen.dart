import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/pages/components/base_page.dart';
import 'package:laptop_controller/pages/components/settings_tile.dart';
import 'package:laptop_controller/pages/settings/widgets/color_picker.dart';
import 'package:laptop_controller/pages/settings/widgets/connection_details.dart';
import 'package:laptop_controller/theme/provider/theme_provider.dart';

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