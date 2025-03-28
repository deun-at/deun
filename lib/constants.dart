import 'package:flutter/material.dart';

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

enum GroupListFilter {
  all('all'),
  active('active'),
  done('done');

  const GroupListFilter(this.value);
  final String value;
}

const spacer = SizedBox(
  height: 12,
);

enum MobileAdMobs {
  // androidGroupList('ca-app-pub-3679753617535056/9759096631'),
  // iosGroupList('ca-app-pub-3679753617535056/8051241217'),
  // androidExpenseList('ca-app-pub-3679753617535056/4893776594'),
  // iosExpenseList('ca-app-pub-3679753617535056/3732722251');
  androidGroupList('ca-app-pub-3940256099942544/2247696110'),
  iosGroupList('ca-app-pub-3940256099942544/3986624511'),
  androidExpenseList('ca-app-pub-3940256099942544/2247696110'),
  iosExpenseList('ca-app-pub-3940256099942544/3986624511');

  const MobileAdMobs(this.value);
  final String value;
}
