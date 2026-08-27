/// A single point-in-time environmental reading for the Dibang Valley study
/// area. Demo-shaped (see services/weather_provider.dart) until a real
/// IMD/weather API is wired up — every screen showing this must say so.
class WeatherObservation {
  final double rainfall24hMm;
  final double soilMoisturePercent;
  final double temperatureCelsius;
  final double windSpeedKmh;

  /// No real sensor network exists yet (see the dashboard's "Sensor
  /// Alerts" summary card) — always 0 until one does, not a fabricated
  /// count.
  final int sensorAlertCount;

  final DateTime lastSatelliteUpdate;
  final DateTime observedAt;

  const WeatherObservation({
    required this.rainfall24hMm,
    required this.soilMoisturePercent,
    required this.temperatureCelsius,
    required this.windSpeedKmh,
    required this.sensorAlertCount,
    required this.lastSatelliteUpdate,
    required this.observedAt,
  });
}

/// A short-range rainfall forecast plus the simple risk trend derived from
/// it — see DemoWeatherProvider's doc comment for how [risk6h]/[risk12h]/
/// [risk24h] are computed. Not a validated hydrological or landslide model.
class WeatherForecast {
  final double forecastRainfallMm;
  final double risk6h;
  final double risk12h;
  final double risk24h;
  final DateTime generatedAt;

  const WeatherForecast({
    required this.forecastRainfallMm,
    required this.risk6h,
    required this.risk12h,
    required this.risk24h,
    required this.generatedAt,
  });
}
