import 'package:latlong2/latlong.dart';
import 'risk_zone.dart';

class DigitalTwinZonePrediction {
  final String zoneId;
  final String locationName;
  final double lat;
  final double lng;
  final double currentRiskScore;
  final RiskLevel currentRiskLevel;
  final double predictedRiskScore;
  final RiskLevel predictedRiskLevel;
  final double riskChange;
  final double distanceFromIncidentKm;
  final String predictionHorizon;
  final String displacementTrend;
  final List<String> contributingFactors;

  const DigitalTwinZonePrediction({
    required this.zoneId,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.currentRiskScore,
    required this.currentRiskLevel,
    required this.predictedRiskScore,
    required this.predictedRiskLevel,
    required this.riskChange,
    required this.distanceFromIncidentKm,
    required this.predictionHorizon,
    required this.displacementTrend,
    required this.contributingFactors,
  });

  LatLng get position => LatLng(lat, lng);
}

class DigitalTwinPredictionResult {
  final String predictionId;
  final DateTime timestamp;
  final String simulationScenario;
  final double forecastHorizonHours;
  final DigitalTwinZonePrediction sourceIncident;
  final DigitalTwinZonePrediction nextEmergentRisk;
  final List<DigitalTwinZonePrediction> candidateRankings;
  final List<String> whySelectedExplanation;
  final List<String> physicalCausalityChain;

  const DigitalTwinPredictionResult({
    required this.predictionId,
    required this.timestamp,
    required this.simulationScenario,
    required this.forecastHorizonHours,
    required this.sourceIncident,
    required this.nextEmergentRisk,
    required this.candidateRankings,
    required this.whySelectedExplanation,
    required this.physicalCausalityChain,
  });
}
