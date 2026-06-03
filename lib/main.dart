import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/config/app_router.dart';
import 'package:laptop_controller/core/handler/provider/service_coordinator_provider.dart';
import 'package:laptop_controller/core/notification/data/notification_service_impl.dart';
import 'package:laptop_controller/core/notification/provider/notification_provider.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/pages/pairing_screen/pairing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'pages/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationService = NotificationServiceImpl();  // No need to initialize
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const SyncOSDesktop(),
    ),
  );
}

class SyncOSDesktop extends ConsumerWidget {
  const SyncOSDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(serviceCoordinatorProvider);

    final paired = ref.watch(pairedProvider);

    Widget homeWidget = paired.when(
      data: (hasPaired) => hasPaired ? const HomeScreen() : const PairingScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const PairingScreen(),
    );


    return MaterialApp(
      title: 'SyncOS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,

      home: homeWidget,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
