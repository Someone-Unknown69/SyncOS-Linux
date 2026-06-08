import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/storage/domain/models/app_settings.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';

// Theme notifier backed by persistent AppSettings
class ThemeNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Default settings while we load persisted settings asynchronously
    final defaultSettings = AppSettings(
      themeMode: ThemeMode.system,
      seedColor: Colors.blue,
    );

    // Load persisted settings and update state when available
    final storage = ref.read(storageServiceProvider);
    storage.getAppSettings().then((saved) {
      if (saved != null) state = saved;
    }).catchError((_) {});

    return defaultSettings;
  }

  void updateThemeMode(ThemeMode mode) {
    final updated = AppSettings(themeMode: mode, seedColor: state.seedColor);
    state = updated;
    ref.read(storageServiceProvider).setAppSettings(updated);
  }

  void updateSeedColor(Color color) {
    final updated = AppSettings(themeMode: state.themeMode, seedColor: color);
    state = updated;
    ref.read(storageServiceProvider).setAppSettings(updated);
  }
}
