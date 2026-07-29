import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/word_search/presentation/screens/home_shell.dart';
import '../features/word_search/data/voice_guide_service.dart';
import '../l10n/app_strings.dart';
import 'appearance_controller.dart';
import 'app_theme.dart';
import 'language_controller.dart';
import 'voice_guide_bubble_overlay.dart';

class WordSearchApp extends StatefulWidget {
  const WordSearchApp({super.key});

  @override
  State<WordSearchApp> createState() => _WordSearchAppState();
}

class _WordSearchAppState extends State<WordSearchApp> {
  final _languageController = LanguageController.instance;
  final _appearanceController = AppearanceController.instance;

  @override
  void initState() {
    super.initState();
    _languageController.load();
    _appearanceController.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_languageController, _appearanceController]),
      builder: (context, _) {
        final voiceLanguageCode =
            _languageController.locale?.languageCode ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        VoiceGuideService.instance.setLanguageCode(voiceLanguageCode);
        return MaterialApp(
          onGenerateTitle: (context) => AppStrings.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: _languageController.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: WordSearchAppTheme.light(_appearanceController.skin),
          darkTheme: WordSearchAppTheme.dark(_appearanceController.skin),
          themeMode: _appearanceController.themeMode,
          builder: (context, child) {
            return VoiceGuideBubbleOverlay(
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeShell(),
        );
      },
    );
  }
}
