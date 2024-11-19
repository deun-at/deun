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

const spacer = SizedBox(
  height: 12,
);