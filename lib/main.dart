import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/local_store.dart';
import 'features/markets/market_api.dart';
import 'features/markets/home_screen.dart';
import 'features/watchlist/dashboard_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.importLocalCredentials();
    final controller = DashboardController(HttpMarketApi(store), store);
    runApp(
      ProviderScope(
        overrides: [dashboardProvider.overrideWithValue(controller)],
        child: const PocketValueApp(),
      ),
    );
    await controller.refresh();
  } on Object {
    runApp(
      MaterialApp(
        theme: pocketTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Não foi possível abrir o armazenamento do PocketValue.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: main,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PocketValueApp extends StatelessWidget {
  const PocketValueApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PocketValue',
    debugShowCheckedModeBanner: false,
    theme: pocketTheme(),
    home: const HomeScreen(),
  );
}
