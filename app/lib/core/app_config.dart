/// Global app configuration. A real Firebase project (ner-landslide-ews)
/// now backs this app — see lib/firebase_options.dart — so
/// [useMockData] is false. Flip it back to true for local UI iteration
/// without touching Firestore; every repository interface reads this
/// single flag to pick its Mock or Firestore implementation.
class AppConfig {
  AppConfig._();

  static const bool useMockData = false;

  // ── Study area: Dibang Valley, Arunachal Pradesh, India ────────────────────
  static const double studyAreaMinLat = 28.10;
  static const double studyAreaMaxLat = 28.95;
  static const double studyAreaMinLng = 95.40;
  static const double studyAreaMaxLng = 96.10;

  static const double studyAreaCenterLat = 28.50;
  static const double studyAreaCenterLng = 95.80;

  static const double defaultMapZoom = 10.0;

  static const String district = 'Dibang Valley';
  static const String stateName = 'Arunachal Pradesh';

  // Mathunli reference village for demo GPS fallback
  static const double fallbackLat = 28.7156;
  static const double fallbackLng = 95.6332;
  static const String fallbackVillageName = 'Near Mathunli Village';

  static bool containsPoint(double lat, double lng) {
    return lat >= studyAreaMinLat &&
        lat <= studyAreaMaxLat &&
        lng >= studyAreaMinLng &&
        lng <= studyAreaMaxLng;
  }
}
