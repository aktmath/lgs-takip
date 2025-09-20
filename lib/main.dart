import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/fcm_services.dart';
import 'services/firestore_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FCMServices.initFCM();
    await FirestoreServices.initFCM();

    await FirestoreServices.createTestData();

    debugPrint('Firebase ve FCM başarıyla başlatıldı');
  } catch (e) {
    debugPrint('Firebase başlatma hatası: $e');
  }

  runApp(const BAIHLApp());
}

class BAIHLApp extends StatelessWidget {
  const BAIHLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BAİHL LGS Takip',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
