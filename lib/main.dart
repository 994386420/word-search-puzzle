import 'dart:async';

import 'package:flutter/material.dart';

import 'app/word_search_app.dart';
import 'features/word_search/data/ad_config.dart';
import 'features/word_search/data/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordSearchApp());
  if (AdConfig.adsEnabled) {
    unawaited(AdService.instance.initialize());
  }
}
