import 'package:flutter/foundation.dart';

import '../../../core/services/risk_service.dart';
import '../../../models/district_risk.dart';

class RiskMapProvider extends ChangeNotifier {
  final RiskService _riskService;

  RiskMapProvider(this._riskService);

  List<DistrictRisk> districts = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      districts = await _riskService.fetchHeatmap();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
