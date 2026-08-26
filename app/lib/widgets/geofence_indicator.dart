import 'package:flutter/material.dart';

/// Circular progress toward entering a geofence. [distanceMeters] is the
/// officer's live distance to the target; [radiusMeters] is the geofence
/// radius (~100m for inspections). Progress is `radius / distance`
/// (capped at 1.0), so it reads as "how close, relatively" rather than an
/// exact percentage of some arbitrary outer bound.
class GeofenceProgressIndicator extends StatelessWidget {
  final double distanceMeters;
  final double radiusMeters;

  const GeofenceProgressIndicator({
    super.key,
    required this.distanceMeters,
    required this.radiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    final within = distanceMeters <= radiusMeters;
    final progress =
        distanceMeters <= 0 ? 1.0 : (radiusMeters / distanceMeters).clamp(0.0, 1.0);
    final color = within ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    within ? Icons.check_circle : Icons.social_distance,
                    color: color,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    within ? 'In range' : '${distanceMeters.toStringAsFixed(0)} m away',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Need to be within ${radiusMeters.toStringAsFixed(0)} m of the target'),
      ],
    );
  }
}
