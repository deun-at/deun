/// Quick date choices offered by the date sheet.
///
/// [today] and [yesterday] resolve to a concrete (date-only) [DateTime]
/// relative to a reference "now"; [pick] is deferred to the platform calendar
/// (`showDatePicker`) and resolves to `null`. The resolved value is the same
/// `DateTime` the picker previously wrote, so the save path is unchanged.
enum DateOption {
  today,
  yesterday,
  pick;

  /// The date this option represents relative to [now] (date-only, midnight),
  /// or `null` for [pick] (which defers to the calendar).
  DateTime? resolve(DateTime now) {
    final dateOnly = DateTime(now.year, now.month, now.day);
    switch (this) {
      case DateOption.today:
        return dateOnly;
      case DateOption.yesterday:
        return dateOnly.subtract(const Duration(days: 1));
      case DateOption.pick:
        return null;
    }
  }

  /// Whether [value] falls on the same calendar day this option resolves to.
  /// Always `false` for [pick].
  bool matches(DateTime value, DateTime now) {
    final resolved = resolve(now);
    if (resolved == null) return false;
    return value.year == resolved.year &&
        value.month == resolved.month &&
        value.day == resolved.day;
  }
}
