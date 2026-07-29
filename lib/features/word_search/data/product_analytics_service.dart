import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProductAnalyticsService {
  ProductAnalyticsService._();

  static final instance = ProductAnalyticsService._();
  static const eventsKey = 'product_events_v1';
  static const maxStoredEvents = 200;

  Future<void> record(
    String name, {
    Map<String, Object?> properties = const {},
    DateTime? now,
  }) async {
    final safeName = name.trim();
    if (safeName.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final events = _decode(prefs.getString(eventsKey));
    events.add({
      'name': safeName,
      'at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'properties': properties.map(
        (key, value) => MapEntry(key, _safeValue(value)),
      ),
    });
    final trimmed = events.length <= maxStoredEvents
        ? events
        : events.sublist(events.length - maxStoredEvents);
    await prefs.setString(eventsKey, jsonEncode(trimmed));
  }

  static List<Map<String, dynamic>> decodeForTesting(String? raw) =>
      _decode(raw);

  static Object? _safeValue(Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    final text = value.toString();
    return text.length <= 64 ? text : text.substring(0, 64);
  }

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
