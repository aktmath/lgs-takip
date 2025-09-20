import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMServices {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initFCM() async {
    // İzin iste
    await _fcm.requestPermission();

    // Token al
    String? token = await _fcm.getToken();
    print('FCM Token: $token');

    // Uygulama açıkken gelen mesajları dinle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'Yeni mesaj geldi: ${message.notification?.title} - ${message.notification?.body}',
      );
      // İsteğe bağlı: SnackBar ile ekranda göster
    });

    // Arka planda veya kapalıyken mesajı yakalamak için
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirim açıldı: ${message.data}');
    });
  }

  // Token'ı Firestore'a kaydet (her kullanıcı için)
  static Future<void> saveTokenToFirestore(String userId) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      // Burada Firestore kullanarak kullanıcıya token'ı kaydedebilirsiniz
      // await FirebaseFirestore.instance.collection('users').doc(userId).update({'fcmToken': token});
      print('Token Firestore\'a kaydedildi: $token');
    }
  }
}
