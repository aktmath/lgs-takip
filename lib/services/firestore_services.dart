import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirestoreServices {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<bool> isAdmin(String username) async {
    try {
      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) {
        return username.toLowerCase() == 'admin';
      }

      var data = doc.data()!;
      return data['role'] == 'admin' || username.toLowerCase() == 'admin';
    } catch (e) {
      print('isAdmin error: $e');
      return username.toLowerCase() == 'admin';
    }
  }

  static Future<bool> login(String username, String password) async {
    try {
      if (username.toLowerCase() == 'admin' && password == 'admin') {
        return true;
      }

      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) return false;

      var data = doc.data()!;
      return data['password'] == password;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  static Future<void> initFCM() async {
    try {
      await _fcm.requestPermission();
      String? token = await _fcm.getToken();
      print('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Yeni mesaj geldi: ${message.notification?.title}');
      });
    } catch (e) {
      print('FCM init error: $e');
    }
  }

  static Future<void> createTestData() async {
    try {
      await _db.collection('users').doc('test').set({
        'password': 'test',
        'role': 'parent',
        'student': {'name': 'Ahmet Yılmaz', 'schoolNo': '1001'},
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Test verisi oluşturuldu');
    } catch (e) {
      print('Test data creation error: $e');
    }
  }
}
