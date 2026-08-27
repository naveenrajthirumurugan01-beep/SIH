import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/citizen_theme.dart';
import '../../models/report.dart';

/// Screen 4: Report Submitted (Status & Tracking) - matching visual reference exactly.
class ReportSubmittedScreen extends StatelessWidget {
  final Report report;

  const ReportSubmittedScreen({super.key, required this.report});

  String get _displayId {
    final date = DateFormat('yyyy-MMdd').format(report.createdAt);
    final rawNum = report.id.replaceAll(RegExp(r'[^0-9]'), '');
    final seq = rawNum.length >= 4
        ? rawNum.substring(rawNum.length - 4)
        : (rawNum.isEmpty ? '0015' : rawNum.padLeft(4, '0'));
    return 'CIT-$date-$seq';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        automaticallyImplyLeading: false,
        title: const Text('Report Submitted', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Green check badge with outer ring / confetti look
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thank You!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your report has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // REPORT ID box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REPORT ID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _displayId,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, color: Colors.black54),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _displayId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report ID copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // What happens next?
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What happens next?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stepper
                _BuildStepItem(
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  title: 'Report Received',
                  subtitle: DateFormat('d MMM yyyy, hh:mm a').format(report.createdAt),
                  isFirst: true,
                  isLast: false,
                  isActive: true,
                ),
                _BuildStepItem(
                  icon: Icons.assignment_turned_in,
                  iconColor: Colors.green,
                  title: 'Under Review',
                  subtitle: 'Our team will verify your report',
                  isFirst: false,
                  isLast: false,
                  isActive: true,
                ),
                _BuildStepItem(
                  icon: Icons.circle_outlined,
                  iconColor: Colors.grey.shade400,
                  title: 'Action Taken',
                  subtitle: 'You will be notified',
                  isFirst: false,
                  isLast: true,
                  isActive: false,
                ),

                const SizedBox(height: 20),

                // Alert notification banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You will receive updates about this report in My Reports',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // VIEW MY REPORTS button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: CitizenTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'VIEW MY REPORTS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildStepItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;
  final bool isActive;

  const _BuildStepItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isFirst,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive ? iconColor.withAlpha(30) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
