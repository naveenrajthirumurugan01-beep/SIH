import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: throws until `flutterfire configure` has been run from app/ to
  // generate real firebase_options.dart values for your Firebase project.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LandslideEwsApp());
}

class LandslideEwsApp extends StatelessWidget {
  const LandslideEwsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(AuthService()),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp.router(
            title: 'NER Landslide EWS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routerConfig: buildRouter(authProvider),
          );
        },
      ),
    );
  }
}
