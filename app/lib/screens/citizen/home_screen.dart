import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';
import '../../models/alert.dart';
import '../../models/report.dart';
import '../../widgets/gis_map_widget.dart';
import '../../widgets/risk_badge.dart';
import 'full_screen_gis_map.dart';
import 'report_hazard_screen.dart';

// ── Synthetic safety tips ────────────────────────────────────────────────────
const _safetyTips = [
  'Avoid steep slopes during heavy rain',
  'Stay away from landslide prone areas',
  'Follow official alerts and instructions',
  'Do not cross flooded streams or roads',
  'Keep emergency contact numbers saved',
  'Move uphill immediately if you hear rumbling sounds',
];

class HomeScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<HazardAlert> _alerts = [];

  // Weather telemetry for Dibang Valley
  final double _rainfall24h = 12.4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = context.read<AppState>();
    
    // Background location refresh (non-blocking for UI render)
    appState.refreshLocation().catchError((_) {});

    final alerts = await appState.alertRepository.getAlerts();

    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  void _openReport(HazardType? preset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportHazardScreen(presetType: preset),
      ),
    );
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullScreenGisMapScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: const Text(
          'Dibang Valley',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => widget.onNavigate(2),
              ),
              if (_alerts.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── 1. Greeting + Rainfall Weather Summary ───────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'Hello, Citizen ',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  Text('👋', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stay alert. Stay safe.',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        // Rainfall weather widget
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '🌧 $_rainfall24h mm',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Text('Rainfall (24h)', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 2. LANDSLIDE RISK MAP (Interactive GIS Weather Map) ─────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Row(
                            children: [
                              const Text(
                                'LANDSLIDE RISK MAP',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _openFullScreenMap,
                                child: Row(
                                  children: const [
                                    Icon(Icons.fullscreen, size: 14, color: CitizenTheme.primary),
                                    SizedBox(width: 2),
                                    Text(
                                      'FULL SCREEN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: CitizenTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Real Interactive GIS & Live Weather Map Component
                        GisMapWidget(
                          height: 240,
                          onOpenFullScreen: _openFullScreenMap,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 3. QUICK ACTIONS ─────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUICK ACTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _QuickAction(
                              icon: Icons.warning_rounded,
                              label: 'REPORT\nLANDSLIDE',
                              bgColor: const Color(0xFFFFEBEE),
                              iconColor: Colors.red.shade700,
                              labelColor: Colors.red.shade700,
                              onTap: () => _openReport(HazardType.landslide),
                            ),
                            const SizedBox(width: 10),
                            _QuickAction(
                              icon: Icons.terrain,
                              label: 'REPORT CRACK/\nROCKFALL',
                              bgColor: const Color(0xFFE8F5E9),
                              iconColor: CitizenTheme.primary,
                              labelColor: CitizenTheme.primary,
                              onTap: () => _openReport(HazardType.crack),
                            ),
                            const SizedBox(width: 10),
                            _QuickAction(
                              icon: Icons.water,
                              label: 'REPORT\nFLOOD/WATER',
                              bgColor: const Color(0xFFE3F2FD),
                              iconColor: Colors.blue.shade700,
                              labelColor: Colors.blue.shade700,
                              onTap: () => _openReport(HazardType.waterSeepage),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 4. SAFETY TIPS ───────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SAFETY TIPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final tip in _safetyTips.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: CitizenTheme.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 5. RECENT ALERTS ─────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'RECENT ALERTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => widget.onNavigate(2),
                              child: const Text(
                                'View All',
                                style: TextStyle(color: CitizenTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_alerts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No active alerts in your area.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          )
                        else
                          for (final alert in _alerts.take(2))
                            _AlertRow(alert: alert),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── 6. MY REPORTS (TRACKING) ─────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MY REPORTS (TRACKING)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MyReportsTable(
                          appState: appState,
                          onViewAll: () => widget.onNavigate(1),
                        ),
                      ],
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withAlpha(50)),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final HazardAlert alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  'Near ${alert.district} · ${DateFormat('d MMM yyyy, hh:mm a').format(alert.createdAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          RiskBadge(level: alert.severity),
        ],
      ),
    );
  }
}

class _MyReportsTable extends StatelessWidget {
  final AppState appState;
  final VoidCallback onViewAll;
  const _MyReportsTable({required this.appState, required this.onViewAll});

  Color _severityColor(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('high') || lower.contains('critical')) {
      return Colors.red;
    }
    if (lower.contains('moderate')) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _statusColor(ReportStatus status) => switch (status) {
        ReportStatus.submitted => Colors.grey,
        ReportStatus.underReview => Colors.blue,
        ReportStatus.fieldVerification => Colors.orange,
        ReportStatus.verified => CitizenTheme.primary,
        ReportStatus.resolved => Colors.teal,
        ReportStatus.rejected => Colors.red,
      };

  String _statusSubtitle(ReportStatus status) => switch (status) {
        ReportStatus.submitted => 'Report logged',
        ReportStatus.underReview => 'Our team is verifying',
        ReportStatus.fieldVerification => 'Team visited the location',
        ReportStatus.verified => 'Verified by field officer',
        ReportStatus.resolved => 'Thank you for your report',
        ReportStatus.rejected => 'Could not verify',
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: appState.reportRepository.watchMyReports(appState.deviceId),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No reports yet. Tap Quick Actions to report a hazard.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: [
            // Header
            Row(
              children: const [
                Expanded(flex: 3, child: Text('Report ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Severity', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(height: 10),
            for (final r in reports.take(4)) ...[
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: r.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report ID copied'), duration: Duration(seconds: 1)),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _shortId(r),
                        style: const TextStyle(fontSize: 10, color: CitizenTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(_hazardIcon(r.hazardType), size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(r.hazardType.label, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Near ${r.district}',
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'High',
                        style: TextStyle(fontSize: 10, color: _severityColor('high'), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.status.label,
                            style: TextStyle(fontSize: 10, color: _statusColor(r.status), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _statusSubtitle(r.status),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 10),
            ],
            if (reports.length > 4)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'View all ${reports.length} reports →',
                    style: const TextStyle(fontSize: 12, color: CitizenTheme.primary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _shortId(Report r) {
    final date = DateFormat('yyyy-MMdd').format(r.createdAt);
    final num = r.id.replaceAll(RegExp(r'[^0-9]'), '');
    final seq = num.length >= 4 ? num.substring(num.length - 4) : num.padLeft(4, '0');
    return 'CIT-$date-$seq';
  }

  IconData _hazardIcon(HazardType t) => switch (t) {
        HazardType.landslide => Icons.landslide_outlined,
        HazardType.crack => Icons.splitscreen_outlined,
        HazardType.rockfall => Icons.terrain,
        HazardType.roadBlockage => Icons.do_not_disturb_on_outlined,
        HazardType.waterSeepage => Icons.water_outlined,
        HazardType.soilMovement => Icons.landscape_outlined,
        HazardType.damagedInfrastructure => Icons.foundation_outlined,
        HazardType.other => Icons.more_horiz,
      };
}
