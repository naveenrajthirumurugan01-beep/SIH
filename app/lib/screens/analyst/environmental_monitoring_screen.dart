import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/risk_zone.dart';
import '../../models/weather.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/stat_tile.dart';

/// Environmental Monitoring Panel (Phase 2, section 4). Backed by
/// [AppState.weatherProvider] — see services/weather_provider.dart for why
/// every value here is demo-shaped rather than a live reading, and for the
/// (non-validated) trend logic behind the 6h/12h/24h risk forecast.
class EnvironmentalMonitoringScreen extends StatefulWidget {
  const EnvironmentalMonitoringScreen({super.key});

  @override
  State<EnvironmentalMonitoringScreen> createState() => _EnvironmentalMonitoringScreenState();
}

class _EnvironmentalMonitoringScreenState extends State<EnvironmentalMonitoringScreen> {
  late Future<(WeatherObservation, WeatherForecast)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(WeatherObservation, WeatherForecast)> _load() async {
    final provider = context.read<AppState>().weatherProvider;
    final observation = await provider.getCurrentObservation();
    final forecast = await provider.getForecast();
    return (observation, forecast);
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<(WeatherObservation, WeatherForecast)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(
              message: 'Could not load environmental data: ${snapshot.error}',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }
          final (observation, forecast) = snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(context.isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DemoDataBanner(),
                const SizedBox(height: 16),
                Text('Dibang Valley — current conditions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ObservationGrid(observation: observation),
                const SizedBox(height: 20),
                Text('Rainfall-driven risk forecast', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ForecastCard(forecast: forecast),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DemoDataBanner extends StatelessWidget {
  const _DemoDataBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No live sensor or weather-API feed is wired up yet. Values below are fixed, '
                'plausible-for-Dibang-Valley demo readings, not real-time measurements.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationGrid extends StatelessWidget {
  final WeatherObservation observation;

  const _ObservationGrid({required this.observation});

  @override
  Widget build(BuildContext context) {
    final satelliteAge = DateTime.now().difference(observation.lastSatelliteUpdate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 560 ? 3 : 2);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            StatTile(
              icon: Icons.water_drop_outlined,
              value: '${observation.rainfall24hMm.toStringAsFixed(1)}mm',
              label: 'Rainfall (24h)',
              color: Colors.blue,
            ),
            StatTile(
              icon: Icons.grain,
              value: '${observation.soilMoisturePercent.toStringAsFixed(0)}%',
              label: 'Soil Moisture',
              color: Colors.brown,
            ),
            StatTile(
              icon: Icons.thermostat_outlined,
              value: '${observation.temperatureCelsius.toStringAsFixed(1)}°C',
              label: 'Temperature',
            ),
            StatTile(
              icon: Icons.air,
              value: '${observation.windSpeedKmh.toStringAsFixed(0)} km/h',
              label: 'Wind Speed',
            ),
            StatTile(
              icon: Icons.sensors_outlined,
              value: observation.sensorAlertCount.toString().padLeft(2, '0'),
              label: 'Sensor Alerts',
            ),
            StatTile(
              icon: Icons.satellite_alt_outlined,
              value: '${satelliteAge.inHours}h ago',
              label: 'Last Satellite Update',
            ),
          ],
        );
      },
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final WeatherForecast forecast;

  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final rainfallLabel = Text(
      'Forecast rainfall: ${forecast.forecastRainfallMm.toStringAsFixed(1)}mm',
      style: Theme.of(context).textTheme.titleSmall,
    );
    final generatedLabel = Text(
      'Generated ${DateFormat('HH:mm').format(forecast.generatedAt)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (context.isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloudy_snowing),
                      const SizedBox(width: 8),
                      Expanded(child: rainfallLabel),
                    ],
                  ),
                  const SizedBox(height: 2),
                  generatedLabel,
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.cloudy_snowing),
                  const SizedBox(width: 8),
                  rainfallLabel,
                  const Spacer(),
                  generatedLabel,
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'Trend-based estimate, not a validated hydrological or landslide-triggering model.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _RiskWindow(label: '6h', risk: forecast.risk6h),
                _RiskWindow(label: '12h', risk: forecast.risk12h),
                _RiskWindow(label: '24h', risk: forecast.risk24h),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskWindow extends StatelessWidget {
  final String label;
  final double risk;

  const _RiskWindow({required this.label, required this.risk});

  // Same 0.75/0.5/0.25 cutoffs used everywhere else a score gets banded
  // into a RiskLevel (zone_detail_panel.dart's _ConceptCard,
  // dev/synthetic_dataset.dart's _levelForScore) — this used to be
  // 0.75/0.55/0.3, a stray inconsistency with no reason behind it.
  RiskLevel get _level {
    if (risk >= 0.75) return RiskLevel.critical;
    if (risk >= 0.5) return RiskLevel.high;
    if (risk >= 0.25) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForRisk(_level);

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('+$label', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: risk.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(risk * 100).toStringAsFixed(0)}% · ${_level.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
