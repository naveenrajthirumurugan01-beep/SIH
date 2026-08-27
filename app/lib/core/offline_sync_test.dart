import '../models/field_evidence.dart';
import '../models/inspection.dart';
import '../services/field_officer_sync_service.dart';

/// Test Suite for Phase 10 Offline Storage & Synchronization
class OfflineSyncTestSuite {
  static Future<Map<String, dynamic>> runTests() async {
    final results = <String, bool>{};

    final syncService = FieldOfficerSyncService();
    await syncService.initialize();

    // 1. Simulate Network Disconnected (Offline Mode)
    syncService.setNetworkAvailable(false);
    results['Test 1 - Offline Mode State Active'] =
        syncService.syncState == FieldSyncState.offline && !syncService.isNetworkAvailable;

    // 2. Save Inspection Draft Locally While Offline
    final draft1 = OfflineInspectionDraft(
      inspectionId: 'INS-OFFLINE-808',
      officerUid: 'officer_delta',
      savedAt: DateTime.now(),
      isSynced: false,
      observation: FieldObservation(
        inspectionId: 'INS-OFFLINE-808',
        officerUid: 'officer_delta',
        crack: CrackStatus.major,
        slopeMovement: SlopeMovement.severe,
        rockfall: true,
        waterSeepage: true,
        roadCondition: RoadCondition.blocked,
        overallObservation: OverallObservation.critical,
        remarks: 'Landslide blocked main patrol route',
        recordedAt: DateTime.now(),
      ),
      evidenceItems: [
        FieldEvidenceItem(
          id: 'EVD-808-01',
          inspectionId: 'INS-OFFLINE-808',
          officerUid: 'officer_delta',
          category: EvidenceCategory.roadDamage,
          localFilePath: '/storage/evd808.jpg',
          fileSizeBytes: 204800,
          mediaType: 'photo',
          latitude: 28.7123,
          longitude: 95.8142,
          gpsAccuracyMeters: 5.0,
          capturedAt: DateTime.now(),
          isZoneVerified: true,
        ),
      ],
    );

    await syncService.saveDraftLocally(draft1);

    results['Test 2 - Draft Saved Locally (Pending Sync Count = 1)'] =
        syncService.pendingSyncCount == 1 &&
        syncService.getDraft('INS-OFFLINE-808') != null &&
        syncService.getDraft('INS-OFFLINE-808')!.isSynced == false;

    // 3. Idempotency Check: Re-save same inspection ID (Must NOT duplicate)
    await syncService.saveDraftLocally(draft1);
    results['Test 3 - Idempotent Draft Saving (No Duplicate Count)'] =
        syncService.localDrafts.length == 1 && syncService.pendingSyncCount == 1;

    // 4. Persistence Roundtrip (Serialization/Deserialization Check)
    final jsonMap = draft1.toJson();
    final restoredDraft = OfflineInspectionDraft.fromJson(jsonMap);
    results['Test 4 - Persistent Draft Serialization Preservation'] =
        restoredDraft.inspectionId == 'INS-OFFLINE-808' &&
        restoredDraft.observation?.crack == CrackStatus.major &&
        restoredDraft.evidenceItems.length == 1 &&
        restoredDraft.evidenceItems.first.id == 'EVD-808-01';

    // 5. Restore Network Connection & Trigger Auto-Sync
    syncService.setNetworkAvailable(true);
    await syncService.triggerAutoSync();

    results['Test 5 - Automatic Synchronization Complete (SYNCED ✓)'] =
        syncService.syncState == FieldSyncState.synced &&
        syncService.pendingSyncCount == 0 &&
        syncService.getDraft('INS-OFFLINE-808')?.isSynced == true;

    return results;
  }
}
