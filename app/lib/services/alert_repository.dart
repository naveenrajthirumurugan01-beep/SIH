import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../models/alert.dart';
import '../models/risk_zone.dart';

abstract class AlertRepository {
  /// All alerts, newest first.
  Future<List<HazardAlert>> getAlerts();

  /// Issues a new alert. Alert issuance is manual/analyst-approved in this
  /// build — see screens/analyst/alerts_screen.dart — there is no
  /// automatic threshold-triggered alerting yet, which is a deliberate
  /// scope decision for this prototype, not a missing feature.
  Future<HazardAlert> createAlert(HazardAlert alert);
}

/// SYNTHETIC — replace me. Seeded alert history for the Anini/Etalin study
/// area, for demo purposes only.
class MockAlertRepository implements AlertRepository {
  static final List<HazardAlert> _alerts = [
    HazardAlert(
      id: 'alert_1',
      title: 'Critical landslide risk — Dri River Slope',
      message:
          'Heavy rainfall over the past 48h has raised risk near the Dri River '
          'Slope to critical. Avoid travel through this area if possible.',
      severity: RiskLevel.critical,
      lat: 28.7891,
      lng: 95.8328,
      radiusKm: 3.0,
      district: AppConfig.district,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    HazardAlert(
      id: 'alert_2',
      title: 'High risk advisory — Ithun Valley Slope',
      message:
          'Slope monitoring indicates elevated risk near Ithun Valley. '
          'Field verification is underway.',
      severity: RiskLevel.high,
      lat: 28.7647,
      lng: 95.8248,
      radiusKm: 2.5,
      district: AppConfig.district,
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    HazardAlert(
      id: 'alert_3',
      title: 'Moderate risk — Etalin Confluence Area',
      message: 'Minor slope movement reported by a field official. Monitoring continues.',
      severity: RiskLevel.moderate,
      lat: 28.7500,
      lng: 95.8500,
      radiusKm: 3.0,
      district: AppConfig.district,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

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
      );
}
