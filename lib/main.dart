import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/config/app_router.dart';
import 'package:laptop_controller/core/handler/provider/service_coordinator_provider.dart';
import 'package:laptop_controller/core/notification/data/notification_service_impl.dart';
import 'package:laptop_controller/core/notification/provider/notification_provider.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/pages/main_layout/main_layout.dart';
import 'package:laptop_controller/pages/pairing_screen/pairing_screen.dart';
import 'package:laptop_controller/theme/provider/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  final notificationService = NotificationServiceImpl();  
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SyncOSDesktop(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SyncOSDesktop extends ConsumerWidget {
  const SyncOSDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(serviceCoordinatorProvider);
    final themeSettings = ref.watch(themeProvider);
    // ref.read(storageServiceProvider).clearPairingToken();

    final paired = ref.watch(pairingStatusProvider);

    Widget homeWidget = paired.when(
      data: (hasPaired) => hasPaired ? const MainLayout() : const PairingScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const PairingScreen(),
    );


    return MaterialApp(
      title: 'SyncOS',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(Brightness.light, themeSettings.seedColor),
      darkTheme: buildTheme(Brightness.dark, themeSettings.seedColor),
      themeMode: themeSettings.themeMode,

      home: homeWidget,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
