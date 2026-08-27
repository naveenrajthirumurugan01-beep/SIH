import 'package:cloud_firestore/cloud_firestore.dart';

import '../dev/synthetic_dataset.dart';
import '../models/alert.dart';

abstract class AlertRepository {
  /// All alerts, newest first.
  Future<List<HazardAlert>> getAlerts();

  /// Issues a new alert. Alert issuance is manual/analyst-approved in this
  /// build — see screens/analyst/alerts_screen.dart — there is no
  /// automatic threshold-triggered alerting yet, which is a deliberate
  /// scope decision for this prototype, not a missing feature.
  Future<HazardAlert> createAlert(HazardAlert alert);

  /// Moves an alert through the Analyst's response workflow (Review →
  /// Acknowledge → Assign → Escalate → Resolve — see
  /// screens/analyst/alerts_screen.dart's action buttons).
  Future<void> updateAlertStatus(String alertId, AlertStatus newStatus);
}

/// SYNTHETIC — replace me. Alerts come from the shared [SyntheticDataset]
/// (see lib/dev/synthetic_dataset.dart), tied to the highest-riskScore
/// zones in that same dataset.
class MockAlertRepository implements AlertRepository {
  static final List<HazardAlert> _alerts = List.of(SyntheticDataset.instance.alerts);

  int _nextId = 1;

  @override
  Future<List<HazardAlert>> getAlerts() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final sorted = List<HazardAlert>.from(_alerts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<HazardAlert> createAlert(HazardAlert alert) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final saved = alert._withId('mock_alert_${_nextId++}');
    _alerts.add(saved);
    return saved;
  }

  @override
  Future<void> updateAlertStatus(String alertId, AlertStatus newStatus) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return;
    _alerts[index] = _alerts[index].copyWith(status: newStatus);
  }
}

/// Reads the `alerts` Firestore collection once a real Firebase project is
/// wired up (see AppConfig.useMockData).
class FirestoreAlertRepository implements AlertRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'alerts';

  @override
  Future<List<HazardAlert>> getAlerts() async {
    final snapshot =
        await _firestore.collection(_collection).orderBy('created_at', descending: true).get();
    return snapshot.docs.map((doc) => HazardAlert.fromFirestore(doc.id, doc.data())).toList();
  }

  @override
  Future<HazardAlert> createAlert(HazardAlert alert) async {
    final docRef = await _firestore.collection(_collection).add(alert.toFirestore());
    return alert._withId(docRef.id);
  }

  @override
  Future<void> updateAlertStatus(String alertId, AlertStatus newStatus) {
    return _firestore
        .collection(_collection)
        .doc(alertId)
        .update({'status': newStatus.firestoreValue});
  }
}

extension _AlertWithId on HazardAlert {
  HazardAlert _withId(String id) => HazardAlert(
        id: id,
        title: title,
        message: message,
        severity: severity,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        district: district,
        createdAt: createdAt,
        status: status,
        source: source,
        recommendedAction: recommendedAction,
      );
}
