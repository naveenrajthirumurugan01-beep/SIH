import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notification setup (FCM). Alerts also go out via SMS
/// (see backend/app/services/sms_service.dart) for areas with poor
/// connectivity — this handles the in-app/push side only.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission();
    // TODO: subscribe to a per-district topic once the user's profile
    // district is known, e.g. _messaging.subscribeToTopic('district_$slug').
    // TODO: register onMessage / onMessageOpenedApp handlers and route
    // to the alerts feature screen.
  }

  Future<void> subscribeToDistrict(String district) {
    final topic = 'district_${district.toLowerCase().replaceAll(' ', '_')}';
    return _messaging.subscribeToTopic(topic);
  }
}
