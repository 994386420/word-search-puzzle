import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/product_analytics_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores only the newest bounded event set', () async {
    for (
      var index = 0;
      index < ProductAnalyticsService.maxStoredEvents + 5;
      index++
    ) {
      await ProductAnalyticsService.instance.record(
        'test_event',
        properties: {'index': index},
        now: DateTime(2026, 7, 14).add(Duration(seconds: index)),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ProductAnalyticsService.eventsKey);
    final events = jsonDecode(raw!) as List<dynamic>;

    expect(events, hasLength(ProductAnalyticsService.maxStoredEvents));
    expect((events.first as Map<String, dynamic>)['properties']['index'], 5);
  });
}
