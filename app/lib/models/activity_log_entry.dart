/// A single recorded Analyst action for the in-session Activity Log (see
/// AppState.recordActivity) — e.g. "Assigned task to Field Officer",
/// "Resolved alert at Dri River Slope". In-memory only, for the demo
/// (session-scoped), not persisted to Firestore.
class ActivityLogEntry {
  final DateTime timestamp;
  final String message;

  const ActivityLogEntry({required this.timestamp, required this.message});
}
