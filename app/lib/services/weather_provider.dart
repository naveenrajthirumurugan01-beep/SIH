import '../dev/synthetic_dataset.dart';
import '../models/weather.dart';

/// Environmental data for the Dibang Valley study area. Structured so a
/// real IMD (India Meteorological Department) API — or any weather
/// service — can implement this same interface later without any UI
/// changes; see DemoWeatherProvider's doc comment for what backs it today.
abstract class WeatherProvider {
  Future<WeatherObservation> getCurrentObservation();
  Future<WeatherForecast> getForecast();
}

/// SYNTHETIC — replace me. There is no real weather API wired up yet, so
/// rainfall/soil moisture are derived from the same [SyntheticDataset]
/// zones the Risk Map and dashboard use (averaged across all zones) rather
/// than being independent hardcoded numbers — this is what keeps the
/// Environmental Monitoring screen's "current conditions" consistent with
/// what the rest of the Analyst dashboard is showing, instead of the two
/// contradicting each other. Temperature/wind have no zone-level signal to
/// derive from, so those stay fixed, plausible-for-the-region constants.
class DemoWeatherProvider implements WeatherProvider {
  double get _avgRainfall24hMm {
    final zones = SyntheticDataset.instance.zones;
    return zones.map((z) => z.rainfall24hMm).reduce((a, b) => a + b) / zones.length;
  }

  double get _avgSoilMoisturePercent {
    final zones = SyntheticDataset.instance.zones;
    return zones.map((z) => z.soilMoisturePercent).reduce((a, b) => a + b) / zones.length;
  }

  @override
  Future<WeatherObservation> getCurrentObservation() async {
    final now = DateTime.now();
    return WeatherObservation(
      rainfall24hMm: _avgRainfall24hMm,
      soilMoisturePercent: _avgSoilMoisturePercent,
      temperatureCelsius: 19.5,
      windSpeedKmh: 12,
      sensorAlertCount: 0,
      lastSatelliteUpdate: now.subtract(const Duration(hours: 4)),
      observedAt: now,
    );
  }

  @override
  Future<WeatherForecast> getForecast() async {
    // Simple demo trend: forecast rainfall running ~30% above the current
    // valley-wide average nudges the risk window scores up proportionally
    // — not a real hydrological/landslide-triggering model.
    final currentRainfallMm = _avgRainfall24hMm;
    final forecastRainfallMm = currentRainfallMm * 1.3;
    final trend = currentRainfallMm <= 0
        ? 0.0
        : ((forecastRainfallMm - currentRainfallMm) / currentRainfallMm).clamp(0.0, 1.0);

    return WeatherForecast(
      forecastRainfallMm: forecastRainfallMm,
      risk6h: (0.45 + trend * 0.15).clamp(0.0, 1.0),
      risk12h: (0.55 + trend * 0.20).clamp(0.0, 1.0),
      risk24h: (0.62 + trend * 0.25).clamp(0.0, 1.0),
      generatedAt: DateTime.now(),
    );
  }
}
