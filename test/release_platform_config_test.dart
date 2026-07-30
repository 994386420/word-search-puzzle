import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile release configuration stays portrait-only', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(androidManifest, contains('android:screenOrientation="portrait"'));
    expect(iosInfoPlist, contains('UIInterfaceOrientationPortrait'));
    expect(iosInfoPlist, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(
      iosInfoPlist,
      contains('<key>UIRequiresFullScreen</key>\n\t<true/>'),
      reason: 'Portrait-only iPad support must opt out of multitasking',
    );
  });

  test('mobile launchers provide a Simplified Chinese app name', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidDefaultName = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final androidChineseName = File(
      'android/app/src/main/res/values-zh/strings.xml',
    ).readAsStringSync();
    final iosChineseName = File(
      'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
    ).readAsStringSync();
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(androidManifest, contains('android:label="@string/app_name"'));
    expect(androidDefaultName, contains('>Word Search<'));
    expect(androidChineseName, contains('>单词搜索<'));
    expect(iosChineseName, contains('"CFBundleDisplayName" = "单词搜索";'));
    expect(iosProject, contains('InfoPlist.strings in Resources'));
    expect(iosProject, contains('"zh-Hans"'));
  });

  test('iOS declares and localizes its microphone purpose string', () {
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final iosChineseStrings = File(
      'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
    ).readAsStringSync();

    expect(iosInfoPlist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(
      iosInfoPlist,
      contains(
        'Word Search uses microphone access to support audio and '
        'pronunciation features.',
      ),
    );
    expect(
      iosChineseStrings,
      contains(
        '"NSMicrophoneUsageDescription" = "单词搜索需要使用麦克风，以支持语音和单词发音相关功能。";',
      ),
    );
  });
}
