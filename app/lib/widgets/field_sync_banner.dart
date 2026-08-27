import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/field_officer_sync_service.dart';

/// Header Banner displaying Field Officer Offline & Sync Status (Phase 10).
/// Renders:
/// - OFFLINE MODE (Orange)
/// - SYNCING... (Blue)
/// - SYNCED ✓ (Green)
class FieldSyncBanner extends StatelessWidget {
  const FieldSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FieldOfficerSyncService>(
      builder: (context, syncService, _) {
        Color bannerColor;
        IconData bannerIcon;
        String bannerTitle;
        String bannerSubtitle;

        switch (syncService.syncState) {
          case FieldSyncState.offline:
            bannerColor = Colors.orange.shade900;
            bannerIcon = Icons.wifi_off_rounded;
            bannerTitle = 'OFFLINE MODE';
            bannerSubtitle = syncService.pendingSyncCount > 0
                ? '${syncService.pendingSyncCount} inspection draft(s) saved locally'
                : 'Saving progress locally to device storage';
            break;
          case FieldSyncState.syncing:
            bannerColor = Colors.blue.shade900;
            bannerIcon = Icons.sync_rounded;
            bannerTitle = 'SYNCING...';
            bannerSubtitle = 'Uploading local drafts to backend cloud database';
            break;
          case FieldSyncState.synced:
            bannerColor = const Color(0xFF2E7D32);
            bannerIcon = Icons.check_circle_outline_rounded;
            bannerTitle = 'SYNCED ✓';
            bannerSubtitle = 'All field observations & evidence synchronized';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: bannerColor.withValues(alpha: 0.12),
          child: Row(
            children: [
              if (syncService.syncState == FieldSyncState.syncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                )
              else
                Icon(bannerIcon, size: 20, color: bannerColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bannerTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: bannerColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      bannerSubtitle,
                      style: TextStyle(fontSize: 11, color: bannerColor.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),

              // Network Simulator Switch Button for Offline Testing
              Tooltip(
                message: syncService.isNetworkAvailable
                    ? 'Simulate Disconnecting Network (Offline Test)'
                    : 'Simulate Restoring Network (Auto-Sync Test)',
                child: TextButton.icon(
                  onPressed: () {
                    syncService.setNetworkAvailable(!syncService.isNetworkAvailable);
                  },
                  icon: Icon(
                    syncService.isNetworkAvailable ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: bannerColor,
                  ),
                  label: Text(
                    syncService.isNetworkAvailable ? 'Simulate Offline' : 'Restore Network',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bannerColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
