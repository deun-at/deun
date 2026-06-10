import 'package:flutter/material.dart';

const String kWebAppBaseUrl = 'https://app.deun.app';

/// Public VAPID key for web push. Overridable at build time so it can be
/// rotated without a code change.
const String kFcmVapidKey = String.fromEnvironment(
  'FCM_VAPID_KEY',
  defaultValue: 'BL4YZRDAw8gBPt37GNhz6ub5UxTtDUdjERYzFOgOI2ZdCqwwBToztXtL9Wj0QwqDfKe4CoBQjcjSP54OG3fjFvE',
);

/// Google OAuth client IDs. Public identifiers, but kept overridable at
/// build time so they can be rotated without a code change.
const String kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '820724879316-jauhp8t8g5r3pmir1r5gsghbn2qchav5.apps.googleusercontent.com',
);
const String kGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue: '820724879316-8sacuk8sjju1rvr878gl9lqin0or5h9d.apps.googleusercontent.com',
);

enum ColorSeed {
  baseColor('Teal', Colors.teal),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  m3Baseline('M3 Baseline', Color(0xff6750a4)),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}

const spacer = SizedBox(
  height: 12,
);

enum MobileAdMobs {
  androidGroupList(String.fromEnvironment('MOBILE_AD_MOB_ANDROID_GROUP_LIST')),
  androidExpenseList(String.fromEnvironment('MOBILE_AD_MOB_ANDROID_EXPENSE_LIST')),
  iosGroupList(String.fromEnvironment('MOBILE_AD_MOB_IOS_GROUP_LIST')),
  iosExpenseList(String.fromEnvironment('MOBILE_AD_MOB_IOS_EXPENSE_LIST'));

  const MobileAdMobs(this.value);
  final String value;
}