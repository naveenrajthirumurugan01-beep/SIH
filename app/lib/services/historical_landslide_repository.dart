import 'package:cloud_firestore/cloud_firestore.dart';

import '../dev/synthetic_dataset.dart';
import '../models/historical_landslide.dart';

abstract class HistoricalLandslideRepository {
  Future<List<HistoricalLandslide>> getHistoricalLandslides();
}

/// SYNTHETIC — replace me. Events come from the shared [SyntheticDataset]
/// (see lib/dev/synthetic_dataset.dart), weighted toward the
/// higher-susceptibility zones — that weighting is also what drives each
/// zone's `historicalEventCount`, not the reverse.
class MockHistoricalLandslideRepository implements HistoricalLandslideRepository {
  static final List<HistoricalLandslide> _events = SyntheticDataset.instance.historicalLandslides;

  @override
  Future<List<HistoricalLandslide>> getHistoricalLandslides() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_events);
  }
}

/// Reads the `historical_landslides` Firestore collection (see
/// firebase/firestore.rules — read-only for every signed-in user, same as
/// risk_zones) once a real Firebase project is wired up.
class FirestoreHistoricalLandslideRepository implements HistoricalLandslideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'historical_landslides';

  @override
  Future<List<HistoricalLandslide>> getHistoricalLandslides() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map((doc) => HistoricalLandslide.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
