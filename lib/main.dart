import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/gateway_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App must always start from gateway screen.
  await FirebaseAuth.instance.signOut();
  await NotificationService.instance.initialize();

  runApp(const WifiMapMidtermApp());
}

class WifiMapMidtermApp extends StatelessWidget {
  const WifiMapMidtermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cari Wifi Paling Kenceng di mana',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          scaffoldBackgroundColor: const Color(0xFFF6F8FA),
          useMaterial3: true,
        ),
        home: const GatewayScreen(),
      ),
    );
  }
}
