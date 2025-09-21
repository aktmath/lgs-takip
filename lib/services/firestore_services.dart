import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirestoreServices {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<bool> isAdmin(String username) async {
    try {
      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) {
        return false; // Hardcoded admin kontrolünü kaldırdık
      }

      var data = doc.data()!;
      return data['role'] == 'admin';
    } catch (e) {
      print('isAdmin error: $e');
      return false; // Hardcoded admin kontrolünü kaldırdık
    }
  }

  static Future<bool> login(String username, String password) async {
    try {
      // Hardcoded admin kontrolünü tamamen kaldırdık
      // Sadece Firebase'deki kullanıcıları kontrol et

      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) {
        print('User not found: $username');
        return false;
      }

      var data = doc.data()!;
      bool passwordMatch = data['password'] == password;

      if (passwordMatch) {
        print('Login successful for user: $username');
        return true;
      } else {
        print('Invalid password for user: $username');
        return false;
      }
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
      // Test kullanıcısını oluştur (sadece yoksa)
      var testDoc = await _db.collection('users').doc('test').get();
      if (!testDoc.exists) {
        await _db.collection('users').doc('test').set({
          'password': 'test',
          'role': 'parent',
          'student': {'name': 'Ahmet Yılmaz', 'schoolNo': '1001'},
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('Test verisi oluşturuldu');
      }

      // Admin kullanıcısını kontrol et ve gerekirse oluştur
      var adminDoc = await _db.collection('users').doc('admin').get();
      if (!adminDoc.exists) {
        await _db.collection('users').doc('admin').set({
          'password': '123456', // Sizin belirlediğiniz şifre
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'system',
        });
        print('Admin hesabı oluşturuldu (username: admin, password: 123456)');
      }
    } catch (e) {
      print('Data creation error: $e');
    }
  }

  // Admin şifre değiştirme için özel fonksiyon
  static Future<bool> changeAdminPassword(
    String username,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) {
        return false;
      }

      var data = doc.data()!;

      // Mevcut şifreyi kontrol et
      if (data['password'] != currentPassword) {
        return false;
      }

      // Admin olduğunu kontrol et
      if (data['role'] != 'admin') {
        return false;
      }

      // Şifreyi güncelle
      await _db.collection('users').doc(username).update({
        'password': newPassword,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'passwordUpdatedBy': username,
      });

      print('Admin password updated successfully');
      return true;
    } catch (e) {
      print('Admin password change error: $e');
      return false;
    }
  }
}
