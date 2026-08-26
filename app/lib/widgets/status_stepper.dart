import 'package:flutter/material.dart';

import '../models/report.dart';

const List<ReportStatus> _forwardStages = [
  ReportStatus.submitted,
  ReportStatus.underReview,
  ReportStatus.fieldVerification,
  ReportStatus.verified,
  ReportStatus.resolved,
];

/// Vertical progress stepper for the report review pipeline. `rejected` is
/// rendered as a distinct terminal banner rather than a stage in the main
/// line, since a report can be rejected from either underReview or
/// fieldVerification.
class StatusStepper extends StatelessWidget {
  final ReportStatus current;

  const StatusStepper({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    if (current == ReportStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('This report was rejected during review.')),
          ],
        ),
      );
    }

    final currentIndex = _forwardStages.indexOf(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _forwardStages.length; i++)
          _StepRow(
            label: _forwardStages[i].label,
            isDone: i < currentIndex,
            isCurrent: i == currentIndex,
            isLast: i == _forwardStages.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _StepRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isDone || isCurrent;
    final dotColor = active ? scheme.primary : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? scheme.primary : Colors.transparent,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: active ? null : scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
