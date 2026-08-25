import '../../models/district_risk.dart';

/// Fetches district risk heatmap data from the FastAPI backend.
///
/// TODO: implement with an http client (e.g. package:http) hitting
/// GET {AppConstants.apiBaseUrl}/risk/heatmap with the Firebase ID token
/// as a Bearer auth header. Stubbed with empty results so the risk map
/// screen can be built against a stable interface first.
class RiskService {
  Future<List<DistrictRisk>> fetchHeatmap() async {
    throw UnimplementedError('TODO: call GET /risk/heatmap on the backend');
  }

  Future<DistrictRisk> fetchDistrictRisk(String district) async {
    throw UnimplementedError('TODO: call GET /risk/district/{district} on the backend');
  }
}
