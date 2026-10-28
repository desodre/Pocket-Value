import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_value/core/local_store.dart';
import 'package:pocket_value/main.dart';
import 'package:pocket_value/features/watchlist/dashboard_controller.dart';

import 'features/watchlist/dashboard_controller_test.dart'
    show FakeApi, apple, petro;

void main() {
  late DashboardController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = DashboardController(
      FakeApi(),
      LocalStore(await SharedPreferences.getInstance()),
    );
  });
  tearDown(() => c.dispose());
  Future<void> mount(
    WidgetTester tester, {
    double width = 400,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardProvider.overrideWithValue(c)],
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: const PocketValueApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty first launch and search dialog are actionable', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('PocketValue'), findsOneWidget);
    expect(find.text('Comece pela sua lista'), findsOneWidget);
    await tester.tap(find.text('Adicionar ativo'));
    await tester.pumpAndSettle();
    expect(find.text('Nome ou símbolo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('populated screen and market filtering', (tester) async {
    await c.add(apple);
    await c.add(petro);
    await c.refresh();
    await mount(tester);
    await tester.tap(find.text('Internacional'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('PETR4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow screen supports large text without layout errors', (
    tester,
  ) async {
    await c.add(apple);
    await c.refresh();
    await mount(tester, width: 320, scale: 2);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('dashboard visual review artifact', (tester) async {
    await c.add(apple);
    await c.add(petro);
    await c.refresh();
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((p) => p['name'] == 'flutter');
      final root = Directory.fromUri(
        configFile.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      for (final entry in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final font = FontLoader(entry.key)
          ..addFont(
            File(
              '${root.path}/bin/cache/artifacts/material_fonts/${entry.value}',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await font.load();
      }
    });
    await mount(tester);
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/pocket-value-home.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
