import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirestoreServices {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Admin kontrol fonksiyonu
  static Future<bool> isAdmin(String username) async {
    try {
      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) return false;
      return doc['role'] == 'admin';
    } catch (e) {
      print('isAdmin error: $e');
      return false;
    }
  }

  // Veli login
  static Future<bool> login(String username, String password) async {
    try {
      var doc = await _db.collection('users').doc(username).get();
      if (!doc.exists) return false;
      return doc['password'] == password;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // FCM başlatma
  static Future<void> initFCM() async {
    await _fcm.requestPermission();
    String? token = await _fcm.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Yeni mesaj geldi: ${message.notification?.title}');
    });
  }

  // Yeni veli ve öğrenciyi ekle
  static Future<void> addParent({
    required String username,
    required String password,
    required String studentName,
    required String studentSurname,
    required String studentNo,
  }) async {
    await _db.collection('users').doc(username).set({
      'password': password,
      'role': 'parent', // Veli hesabı
      'student': {
        'name': studentName,
        'surname': studentSurname,
        'schoolNo': studentNo,
      },
      'exams': [],
      'books': [],
      'weeklyQuestions': [],
      'announcements': [],
      'notifications': [],
    });
  }

  // Duyuru gönderme: seçili kullanıcı
  static Future<void> sendAnnouncementToUser(
    String username,
    String message,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(username)
          .collection('announcements')
          .add({'message': message, 'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      print('sendAnnouncementToUser error: $e');
      throw e;
    }
  }

  // Duyuru gönderme: tüm kullanıcılar
  static Future<void> sendAnnouncementToAll(String message) async {
    try {
      var usersSnapshot = await _db.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        await userDoc.reference.collection('announcements').add({
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('sendAnnouncementToAll error: $e');
      throw e;
    }
  }

  // Yoklama bildirimi gönderme
  static Future<void> sendAbsenceNotification(String username) async {
    try {
      await _db
          .collection('users')
          .doc(username)
          .collection('notifications')
          .add({
            'type': 'absence',
            'message': 'Öğrenciniz bugün okula gelmedi.',
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('sendAbsenceNotification error: $e');
      throw e;
    }
  }

  // Öğrencinin deneme bilgilerini ekle
  static Future<void> addExam({
    required String username,
    required String studentName,
    required String date,
    required int score,
  }) async {
    final userDoc = _db.collection('users').doc(username);
    final userSnapshot = await userDoc.get();
    if (!userSnapshot.exists) throw 'Veli bulunamadı';

    List exams = userSnapshot['exams'] ?? [];
    exams.add({'studentName': studentName, 'date': date, 'score': score});

    await userDoc.update({'exams': exams});
  }

  // Öğrenci verilerini çek
  static Future<Map<String, dynamic>> getStudentData(
    String parentUsername,
  ) async {
    try {
      var doc = await _db.collection('users').doc(parentUsername).get();
      if (!doc.exists) return {};
      var data = doc.data() ?? {};

      // Eksik alanları boş liste veya map ile doldur
      data['exams'] = data['exams'] ?? [];
      data['books'] = data['books'] ?? [];
      data['weeklyQuestions'] = data['weeklyQuestions'] ?? [];
      data['announcements'] = data['announcements'] ?? [];
      data['notifications'] = data['notifications'] ?? [];
      return data;
    } catch (e) {
      print('getStudentData error: $e');
      return {};
    }
  }
}
