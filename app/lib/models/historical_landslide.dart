/// A past landslide event somewhere inside the Dibang Valley study area,
/// shown on the Risk Map as a "Historical Landslides" layer (Analyst
/// dashboard, Phase 2 section 5). Backed either by
/// MockHistoricalLandslideRepository (synthetic, seeded) or
/// FirestoreHistoricalLandslideRepository (reads the
/// `historical_landslides` collection) — see
/// lib/services/historical_landslide_repository.dart.
class HistoricalLandslide {
  final String id;
  final String locationName;
  final double lat;
  final double lng;
  final DateTime eventDate;
  final String severity;

  /// Where this record came from — a real source name for seeded entries,
  /// or 'Field officer report' / 'Analyst entry' for in-app ones. Never
  /// fabricated as an authoritative geological survey citation.
  final String source;

  /// Optional id of a `risk_zones` doc this event is associated with.
  final String? relatedZoneId;

  const HistoricalLandslide({
    required this.id,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.eventDate,
    required this.severity,
    required this.source,
    this.relatedZoneId,
  });

  factory HistoricalLandslide.fromFirestore(String id, Map<String, dynamic> data) {
    return HistoricalLandslide(
      id: id,
      locationName: data['location_name'] as String? ?? 'Unnamed location',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      eventDate: DateTime.tryParse(data['event_date'] as String? ?? '') ?? DateTime.now(),
      severity: data['severity'] as String? ?? 'Unknown',
      source: data['source'] as String? ?? 'Unknown',
      relatedZoneId: data['related_zone_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'location_name': locationName,
        'lat': lat,
        'lng': lng,
        'event_date': eventDate.toIso8601String(),
        'severity': severity,
        'source': source,
        'related_zone_id': relatedZoneId,
      };
}
