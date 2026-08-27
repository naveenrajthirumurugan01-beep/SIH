import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/geo_utils.dart';
import '../dev/synthetic_dataset.dart';
import '../models/risk_zone.dart';

abstract class RiskRepository {
  Future<List<RiskZone>> getRiskZones();

  /// Nearest zone to (lat, lng), or null if no zones are loaded.
  Future<RiskZone?> getNearestZone(double lat, double lng);
}

/// SYNTHETIC — replace me. Zones come from the shared
/// [SyntheticDataset] (see lib/dev/synthetic_dataset.dart) so every field
/// — including riskScore/level/historicalEventCount — is generated
/// together and stays internally consistent, rather than each repository
/// inventing its own independent numbers.
class MockRiskRepository implements RiskRepository {
  static final List<RiskZone> _zones = SyntheticDataset.instance.zones;

  @override
  Future<List<RiskZone>> getRiskZones() async {
    // Simulate network latency so loading states are exercised in the UI.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_zones);
  }

  @override
  Future<RiskZone?> getNearestZone(double lat, double lng) async {
    if (_zones.isEmpty) return null;
    RiskZone? nearest;
    var nearestKm = double.infinity;
    for (final zone in _zones) {
      final km = distanceKm(lat, lng, zone.lat, zone.lng);
      if (km < nearestKm) {
        nearestKm = km;
        nearest = zone;
      }
    }
    return nearest;
  }
}

/// Reads the `risk_zones` Firestore collection once a real Firebase project
/// is wired up (see AppConfig.useMockData).
class FirestoreRiskRepository implements RiskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'risk_zones';

  @override
  Future<List<RiskZone>> getRiskZones() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => RiskZone.fromFirestore(doc.id, doc.data())).toList();
  }

  @override
  Future<RiskZone?> getNearestZone(double lat, double lng) async {
    final zones = await getRiskZones();
    if (zones.isEmpty) return null;
    RiskZone? nearest;
    var nearestKm = double.infinity;
    for (final zone in zones) {
      final km = distanceKm(lat, lng, zone.lat, zone.lng);
      if (km < nearestKm) {
        nearestKm = km;
        nearest = zone;
      }
    }
    return nearest;
  }
}
