import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMServices {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initFCM() async {
    await _fcm.requestPermission();

    String? token = await _fcm.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'Yeni mesaj geldi: ${message.notification?.title} - ${message.notification?.body}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirim açıldı: ${message.data}');
    });
  }

  static Future<void> saveTokenToFirestore(String userId) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      print('Token Firestore\'a kaydedildi: $token');
    }
  }
}
