import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';
import '../../models/digital_twin_prediction.dart';
import '../../models/risk_zone.dart';
import '../../services/digital_twin_repository.dart';
import '../../widgets/gis_map_widget.dart';
import '../../widgets/risk_badge.dart';

class CitizenDigitalTwinScreen extends StatefulWidget {
  const CitizenDigitalTwinScreen({super.key});

  @override
  State<CitizenDigitalTwinScreen> createState() => _CitizenDigitalTwinScreenState();
}

class _CitizenDigitalTwinScreenState extends State<CitizenDigitalTwinScreen> {
  final DigitalTwinRepository _repository = DigitalTwinRepository();

  bool _loading = true;
  DigitalTwinPredictionResult? _prediction;

  // Timeline state: 0 -> NOW, 1 -> +6h, 2 -> +12h, 3 -> +18h, 4 -> +24h
  int _timeStepIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;

  static const List<String> _timeLabels = ['NOW', '+6 HOURS', '+12 HOURS', '+18 HOURS', '+24 HOURS'];

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrediction() async {
    setState(() => _loading = true);
    try {
      final res = await _repository.getLatestPrediction();
      if (!mounted) return;
      setState(() {
        _prediction = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _playbackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!mounted) return;
        setState(() {
          _timeStepIndex = (_timeStepIndex + 1) % _timeLabels.length;
        });
      });
    }
  }

  void _showTraceabilitySheet(DigitalTwinPredictionResult pred) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WhyThisZoneSheet(prediction: pred),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'DIGITAL TWIN — EMERGING RISK',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Dibang Valley Predictive Monitoring',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Simulation',
            onPressed: _loadPrediction,
          ),
        ],
      ),
      body: _loading || _prediction == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. DIRECT SAFETY WARNING CARD ───────────────────────
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFEBEE),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '⚠️ ADVANCE SAFETY WARNING',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'A landslide risk is developing in your monitored area near Mathunli East Ridge. '
                                'Avoid unnecessary travel through the affected zone and follow official safety instructions.',
                                style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 2. GIS MAP VISUALIZATION WITH OVERLAYS ──────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.map, size: 16, color: CitizenTheme.primary),
                                const SizedBox(width: 6),
                                const Text(
                                  'PREDICTIVE LANDSLIDE RISK MAP',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _timeLabels[_timeStepIndex],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Satellite GIS Map
                        GisMapWidget(
                          height: 280,
                        ),

                        const SizedBox(height: 10),

                        // ── 3. TIMELINE & PLAY/PAUSE CONTROLS ─────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                                iconSize: 32,
                                color: CitizenTheme.primary,
                                onPressed: _togglePlayback,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(_timeLabels.length, (idx) {
                                      final selected = idx == _timeStepIndex;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text(
                                            _timeLabels[idx],
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: selected ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          selected: selected,
                                          selectedColor: CitizenTheme.primary,
                                          backgroundColor: Colors.white,
                                          onSelected: (_) {
                                            setState(() => _timeStepIndex = idx);
                                          },
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 4. CURRENT AFFECTED ZONE vs NEXT EMERGENT RISK ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        // Current Affected Zone Card
                        _ZoneCard(
                          title: 'CURRENT AFFECTED ZONE',
                          zoneId: _prediction!.sourceIncident.zoneId,
                          locationName: _prediction!.sourceIncident.locationName,
                          riskLevel: _prediction!.sourceIncident.currentRiskLevel,
                          timeHorizon: 'Active Incident Now',
                          distanceKm: '0.0 km',
                          isCurrent: true,
                        ),

                        const SizedBox(height: 10),

                        // Next Emergent Risk Card
                        _ZoneCard(
                          title: 'NEXT EMERGENT RISK ZONE',
                          zoneId: _prediction!.nextEmergentRisk.zoneId,
                          locationName: _prediction!.nextEmergentRisk.locationName,
                          riskLevel: _prediction!.nextEmergentRisk.predictedRiskLevel,
                          timeHorizon: _prediction!.nextEmergentRisk.predictionHorizon,
                          distanceKm: '${_prediction!.nextEmergentRisk.distanceFromIncidentKm} km from incident',
                          riskChange: '+${_prediction!.nextEmergentRisk.riskChange.toStringAsFixed(2)}',
                          isCurrent: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 5. WHY THIS ZONE? TRACEABILITY BUTTON ───────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.help_outline, color: CitizenTheme.primary),
                        label: const Text(
                          'WHY THIS ZONE? (PREDICTION FACTORS)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CitizenTheme.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: CitizenTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showTraceabilitySheet(_prediction!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _ZoneCard extends StatelessWidget {
  final String title;
  final String zoneId;
  final String locationName;
  final RiskLevel riskLevel;
  final String timeHorizon;
  final String distanceKm;
  final String? riskChange;
  final bool isCurrent;

  const _ZoneCard({
    required this.title,
    required this.zoneId,
    required this.locationName,
    required this.riskLevel,
    required this.timeHorizon,
    required this.distanceKm,
    this.riskChange,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.red.shade300 : Colors.orange.shade400,
          width: isCurrent ? 1.5 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isCurrent ? Colors.red.shade200 : Colors.orange.shade300),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.red.shade800 : Colors.orange.shade900,
                  ),
                ),
              ),
              RiskBadge(level: riskLevel),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                zoneId,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationName,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prediction Horizon', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(timeHorizon, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Distance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(distanceKm, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              if (riskChange != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Risk Growth', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(riskChange!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhyThisZoneSheet extends StatelessWidget {
  final DigitalTwinPredictionResult prediction;
  const _WhyThisZoneSheet({required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: CitizenTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'WHY THIS ZONE IS AT EMERGING RISK',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Target Zone: ${prediction.nextEmergentRisk.zoneId} (${prediction.nextEmergentRisk.locationName})',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 20),
          const Text(
            'CONTRIBUTING PHYSICAL FACTORS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          for (final factor in prediction.nextEmergentRisk.contributingFactors)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: CitizenTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(factor, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'PHYSICAL CAUSALITY CHAIN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < prediction.whySelectedExplanation.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                prediction.whySelectedExplanation[i],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.3),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CitizenTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('GOT IT'),
            ),
          ),
        ],
      ),
    );
  }
}
