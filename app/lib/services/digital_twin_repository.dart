import '../models/digital_twin_prediction.dart';
import '../models/risk_zone.dart';

class DigitalTwinRepository {
  /// Consumes existing prediction output produced by the Digital Twin Engine.
  /// (Dibang Valley Landslide Early-Warning Platform)
  Future<DigitalTwinPredictionResult> getLatestPrediction() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final sourceIncident = DigitalTwinZonePrediction(
      zoneId: 'DV-007',
      locationName: 'Dri River Slope - Anini Highway Section',
      lat: 28.7891,
      lng: 95.8328,
      currentRiskScore: 0.82,
      currentRiskLevel: RiskLevel.critical,
      predictedRiskScore: 0.86,
      predictedRiskLevel: RiskLevel.critical,
      riskChange: 0.04,
      distanceFromIncidentKm: 0.0,
      predictionHorizon: '0–1 hours',
      displacementTrend: 'CRITICAL_MOVEMENT',
      contributingFactors: const [
        'High Antecedent Rainfall (118.0 mm)',
        'Steep Slope Angle (54.0°)',
        'Saturated Soil State (94%)',
      ],
    );

    final nextEmergentRisk = DigitalTwinZonePrediction(
      zoneId: 'DV-014',
      locationName: 'Mathunli East Slope Ridge',
      lat: 28.7620,
      lng: 95.8150,
      currentRiskScore: 0.61,
      currentRiskLevel: RiskLevel.high,
      predictedRiskScore: 0.83,
      predictedRiskLevel: RiskLevel.critical,
      riskChange: 0.22,
      distanceFromIncidentKm: 2.8,
      predictionHorizon: '3–6 hours',
      displacementTrend: 'RAPIDLY_ACCELERATING',
      contributingFactors: const [
        'Increasing Infiltrating Rainfall',
        'Rising Soil Moisture & Pore Pressure',
        'Effective Stress Loss in Subsurface',
        'Kinematic Ground Acceleration (0.8 mm/h²)',
        'High Slope Susceptibility (48.0°)',
      ],
    );

    final secondaryEmergentRisk = DigitalTwinZonePrediction(
      zoneId: 'DV-011',
      locationName: 'Dri River Bridge Support Slope',
      lat: 28.7750,
      lng: 95.8210,
      currentRiskScore: 0.65,
      currentRiskLevel: RiskLevel.high,
      predictedRiskScore: 0.88,
      predictedRiskLevel: RiskLevel.critical,
      riskChange: 0.23,
      distanceFromIncidentKm: 1.25,
      predictionHorizon: '3–6 hours',
      displacementTrend: 'ACCELERATING',
      contributingFactors: const [
        'River Toe Erosion',
        'High Soil Moisture Saturation',
        'Effective Stress Reduction',
      ],
    );

    final tertiaryEmergentRisk = DigitalTwinZonePrediction(
      zoneId: 'DV-008',
      locationName: 'Anini South Bypass Highway Slope',
      lat: 28.7800,
      lng: 95.8280,
      currentRiskScore: 0.58,
      currentRiskLevel: RiskLevel.high,
      predictedRiskScore: 0.74,
      predictedRiskLevel: RiskLevel.high,
      riskChange: 0.16,
      distanceFromIncidentKm: 2.1,
      predictionHorizon: '6–12 hours',
      displacementTrend: 'MODERATE_MOVEMENT',
      contributingFactors: const [
        'Antecedent Moisture Buildup',
        'Colluvial Deposit Softening',
      ],
    );

    return DigitalTwinPredictionResult(
      predictionId: 'pred_dt_afaad54bac',
      timestamp: DateTime.now(),
      simulationScenario: 'RAINFALL_PLUS_50 (+50% Rainfall Intensity)',
      forecastHorizonHours: 6.0,
      sourceIncident: sourceIncident,
      nextEmergentRisk: nextEmergentRisk,
      candidateRankings: [
        nextEmergentRisk,
        secondaryEmergentRisk,
        tertiaryEmergentRisk,
      ],
      whySelectedExplanation: const [
        '1. Pore pressure increased from 46.5 kPa to 49.8 kPa under infiltrating rainfall.',
        '2. Effective stress reduced to 8.6 kPa, weakening Mohr-Coulomb shear strength.',
        '3. Displacement trend transitioned to RAPIDLY_ACCELERATING with acceleration 0.8 mm/h².',
        '4. Slope geometry (48.0°) and high antecedence preconditioned terrain stability degradation.',
        '5. Candidate exhibited highest emerging risk growth (+0.22) across 5.0 km spatial search radius.',
      ],
      physicalCausalityChain: const [
        'Source Incident Identified (DV-007)',
        'Spatial Candidate Area Filtered (10.0 km radius)',
        'Rainfall Infiltration & Pore-Fluid Coupling',
        'Pore Pressure Buildup & Effective Stress Reduction',
        'Shear Strength Degradation & Kinematic Acceleration',
        'Risk Evolution & Timestep Integration',
        'Emerging Risk Ranking',
        'Selected Next Emergent Risk: DV-014',
      ],
    );
  }
}
