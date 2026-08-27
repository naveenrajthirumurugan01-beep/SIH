/// Global app configuration. A real Firebase project (ner-landslide-ews)
/// now backs this app — see lib/firebase_options.dart — so
/// [useMockData] is false. Flip it back to true for local UI iteration
/// without touching Firestore; every repository interface reads this
/// single flag to pick its Mock or Firestore implementation.
class AppConfig {
  AppConfig._();

  static const bool useMockData = false;

  // Study area: Anini/Etalin, Dibang Valley, Arunachal Pradesh.
  // Do not change without re-validating against the source imagery/GIS data.
  static const double studyAreaMinLat = 28.60;
  static const double studyAreaMaxLat = 28.85;
  static const double studyAreaMinLng = 95.70;
  static const double studyAreaMaxLng = 96.00;

  static const double studyAreaCenterLat =
      (studyAreaMinLat + studyAreaMaxLat) / 2;
  static const double studyAreaCenterLng =
      (studyAreaMinLng + studyAreaMaxLng) / 2;

  static const double defaultMapZoom = 11.0;

  static const String district = 'Dibang Valley';
  static const String stateName = 'Arunachal Pradesh';

  static bool containsPoint(double lat, double lng) {
    return lat >= studyAreaMinLat &&
        lat <= studyAreaMaxLat &&
        lng >= studyAreaMinLng &&
        lng <= studyAreaMaxLng;
  }
}
