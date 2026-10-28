import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this.preferences, {FlutterSecureStorage? secrets})
    : secrets = secrets ?? const FlutterSecureStorage();
  final SharedPreferences preferences;
  final FlutterSecureStorage secrets;
  Map<String, dynamic> read() {
    try {
      return jsonDecode(preferences.getString('dashboard.v1') ?? '{}')
          as Map<String, dynamic>;
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> save(Map<String, dynamic> state) async {
    if (!await preferences.setString('dashboard.v1', jsonEncode(state))) {
      throw StateError('Não foi possível salvar a lista.');
    }
  }

  Future<String> key(String provider) async =>
      await secrets.read(key: provider) ?? '';
  Future<void> setKey(String provider, String value) async {
    if (value.trim().isEmpty) {
      await secrets.delete(key: provider);
    } else {
      await secrets.write(key: provider, value: value.trim());
    }
  }

  // Persist the local credit budget across app restarts. Other clients sharing
  // this key can consume credits too; the server remains authoritative.
  Future<void> _creditQueue = Future.value();
  Future<void> reserveCredit(DateTime now) {
    final operation = _creditQueue.then((_) => _reserveCredit(now));
    _creditQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _reserveCredit(DateTime now) async {
    final day = now.toUtc().toIso8601String().substring(0, 10);
    final savedDay = preferences.getString('credits.day');
    final count = savedDay == day
        ? preferences.getInt('credits.count') ?? 0
        : 0;
    final recent = (preferences.getStringList('credits.recent') ?? [])
        .map(DateTime.parse)
        .where((t) => now.difference(t) < const Duration(minutes: 1))
        .toList();
    if (count >= 800) {
      throw StateError('Limite local de 800 créditos diários atingido.');
    }
    if (recent.length >= 8) {
      throw StateError(
        'Limite de 8 créditos por minuto. Tente novamente em um minuto.',
      );
    }
    await preferences.setString('credits.day', day);
    await preferences.setInt('credits.count', count + 1);
    await preferences.setStringList(
      'credits.recent',
      [...recent, now].map((t) => t.toIso8601String()).toList(),
    );
  }
}
