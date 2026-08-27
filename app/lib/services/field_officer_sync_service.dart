import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/field_evidence.dart';
import '../models/location_verification.dart';

enum FieldSyncState {
  synced, // SYNCED ✓
  offline, // OFFLINE MODE
  syncing, // SYNCING...
}

/// Offline Inspection Draft record retained locally with stable identifiers
class OfflineInspectionDraft {
  final String inspectionId;
  final String officerUid;
  final LocationVerificationRecord? verificationRecord;
  final List<FieldEvidenceItem> evidenceItems;
  final DateTime savedAt;
  final bool isSynced;

  const OfflineInspectionDraft({
    required this.inspectionId,
    required this.officerUid,
    required this.savedAt,
    this.verificationRecord,
    this.evidenceItems = const [],
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
        'inspection_id': inspectionId,
        'officer_uid': officerUid,
        'saved_at': savedAt.toIso8601String(),
        'is_synced': isSynced,
        'verification_record': verificationRecord?.toFirestore(),
        'evidence_items': evidenceItems.map((e) => e.toFirestore()).toList(),
      };

  factory OfflineInspectionDraft.fromJson(Map<String, dynamic> json) {
    final evdList = (json['evidence_items'] as List? ?? [])
        .map((e) => FieldEvidenceItem.fromFirestore(e as Map<String, dynamic>))
        .toList();

    return OfflineInspectionDraft(
      inspectionId: json['inspection_id'] as String? ?? '',
      officerUid: json['officer_uid'] as String? ?? '',
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
      isSynced: json['is_synced'] as bool? ?? false,
      verificationRecord: json['verification_record'] != null
          ? LocationVerificationRecord.fromFirestore(
              json['verification_record'] as Map<String, dynamic>)
          : null,
      evidenceItems: evdList,
    );
  }
}

/// Offline Storage & Synchronization Engine for Field Officer (Phase 10)
class FieldOfficerSyncService extends ChangeNotifier {
  static const String _draftPrefix = 'field_draft_v1_';

  FieldSyncState _syncState = FieldSyncState.synced;
  FieldSyncState get syncState => _syncState;

  bool _isNetworkAvailable = true;
  bool get isNetworkAvailable => _isNetworkAvailable;

  final Map<String, OfflineInspectionDraft> _localDrafts = {};
  Map<String, OfflineInspectionDraft> get localDrafts => UnmodifiableMapView(_localDrafts);
  int get pendingSyncCount => _localDrafts.values.where((d) => !d.isSynced).length;

  /// Load persisted offline drafts on app startup
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_draftPrefix));

    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final draft = OfflineInspectionDraft.fromJson(map);
          _localDrafts[draft.inspectionId] = draft;
        } catch (_) {}
      }
    }

    _updateSyncState();
  }

  /// Toggle simulated network status (for offline testing)
  void setNetworkAvailable(bool available) {
    _isNetworkAvailable = available;
    _updateSyncState();
    if (_isNetworkAvailable && pendingSyncCount > 0) {
      triggerAutoSync();
    } else {
      notifyListeners();
    }
  }

  /// Save inspection progress locally (offline safe, idempotent by inspectionId)
  Future<void> saveDraftLocally(OfflineInspectionDraft draft) async {
    _localDrafts[draft.inspectionId] = draft;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_draftPrefix${draft.inspectionId}',
      jsonEncode(draft.toJson()),
    );

    _updateSyncState();
    notifyListeners();
  }

  /// Get locally saved draft for an inspection ID
  OfflineInspectionDraft? getDraft(String inspectionId) => _localDrafts[inspectionId];

  /// Trigger automatic synchronization when network is available
  Future<void> triggerAutoSync() async {
    if (!_isNetworkAvailable || pendingSyncCount == 0) return;

    _syncState = FieldSyncState.syncing;
    notifyListeners();

    // Simulate backend sync delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final prefs = await SharedPreferences.getInstance();

    // Idempotent sync loop: Mark each draft as synced using stable IDs
    final pendingDrafts = _localDrafts.values.where((d) => !d.isSynced).toList();
    for (final draft in pendingDrafts) {
      final syncedDraft = OfflineInspectionDraft(
        inspectionId: draft.inspectionId,
        officerUid: draft.officerUid,
        savedAt: draft.savedAt,
        verificationRecord: draft.verificationRecord,
        evidenceItems: draft.evidenceItems,
        isSynced: true, // Synced flag updated
      );

      _localDrafts[draft.inspectionId] = syncedDraft;
      await prefs.setString(
        '$_draftPrefix${draft.inspectionId}',
        jsonEncode(syncedDraft.toJson()),
      );
    }

    _syncState = FieldSyncState.synced;
    notifyListeners();
  }

  void _updateSyncState() {
    if (!_isNetworkAvailable) {
      _syncState = FieldSyncState.offline;
    } else if (pendingSyncCount > 0) {
      _syncState = FieldSyncState.syncing;
    } else {
      _syncState = FieldSyncState.synced;
    }
  }
}
