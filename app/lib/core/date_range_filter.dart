/// Simple date-range presets shared by every Analyst screen that needed a
/// "when" filter (Reports Queue, Alerts, Risk Map's Historical Landslides
/// layer) — a fixed set of presets rather than a custom date-range picker,
/// since that's enough to make each list filterable without the extra UI
/// surface a picker would need.
enum DateRangePreset { last7Days, last30Days, allTime }

extension DateRangePresetX on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.last7Days => 'Last 7 days',
        DateRangePreset.last30Days => 'Last 30 days',
        DateRangePreset.allTime => 'All time',
      };

  /// Whether [dateTime] falls inside this preset's window, evaluated
  /// against the current moment each time it's called.
  bool includes(DateTime dateTime) {
    if (this == DateRangePreset.allTime) return true;
    final days = this == DateRangePreset.last7Days ? 7 : 30;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return dateTime.isAfter(cutoff);
  }
}
