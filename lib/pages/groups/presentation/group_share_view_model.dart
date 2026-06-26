import 'package:flutter/material.dart';

import 'package:deun/widgets/theme_builder.dart';

/// Below this absolute amount a balance is treated as settled (mirrors the
/// rounding threshold used throughout group share displays).
const double _settledThreshold = 0.005;

/// Maps a share/balance [amount] to its semantic display color.
///
/// - positive (you're owed) and settled (≈ 0) -> [SemanticColors.success]
/// - negative (you owe) -> [SemanticColors.danger]
///
/// Pure so it can be unit-tested without a widget tree; flips with brightness
/// because [semantic] is resolved from the theme by the caller.
Color shareBalanceColor(double amount, SemanticColors semantic) {
  if (amount > _settledThreshold) return semantic.success;
  if (amount < -_settledThreshold) return semantic.danger;
  return semantic.success;
}
