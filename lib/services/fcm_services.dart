import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMServices {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initFCM({BuildContext? context}) async {
    try {
      // Permission isteme
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('FCM Permission Status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted FCM permission');
      } else {
        print('User declined FCM permission');
        return;
      }

      // Local notifications initialize
      await _initLocalNotifications();

      // FCM token al ve yazdır
      String? token = await _fcm.getToken();
      if (token != null) {
        print('=== FCM TOKEN ===');
        print(token);
        print('=================');
      }

      // Foreground presentation options ayarla
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages - BURADA ÖNEMLİ!
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // App açıldığında bildirim tıklanması
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // App kapalıyken bildirim tıklanması
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      print('FCM services initialized successfully');
    } catch (e) {
      print('FCM initialization error: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(initializationSettings);

    // Android için notification channel oluştur
    await _createNotificationChannel();
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lgs_channel',
      'LGS Bildirimler',
      description: 'LGS takip sistemi bildirimleri',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('=== FOREGROUND MESSAGE RECEIVED ===');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('===================================');

    // Hem data hem notification göster
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    String title =
        message.notification?.title ?? message.data['title'] ?? '8B LGS Takip';
    String body =
        message.notification?.body ??
        message.data['body'] ??
        'Yeni bildirim var';

    // Unique notification ID
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'lgs_channel',
          'LGS Bildirimler',
          channelDescription: 'LGS takip sistemi bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: 1,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );

    print('Local notification shown with ID: $notificationId');
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.data}');
    // Buraya bildirime tıklandığında yapılacak işlemleri ekleyin
  }

  // Token'ı Firestore'a kaydet - ÖNEMLİ!
  static Future<void> saveTokenToFirestore(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM Token saved to Firestore for user: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Push notification gönder (SERVER KEY GEREKLİ)
  static Future<void> sendNotificationToUser({
    required String userToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      const String serverKey = 'SERVER_KEY_BURAYA'; // Firebase console'dan alın

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: json.encode({
          'to': userToken,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
          },
          'data': data ?? {},
          'priority': 'high',
          'content_available': true,
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('Failed to send notification: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Firestore trigger ile bildirim gönder
  static Future<void> sendNotificationViaFirestore({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    Map<String, String>? data,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
      print('Notification queued for user: $userId');
    } catch (e) {
      print('Error queueing notification: $e');
    }
  }

  // Test için bildirim gönderme fonksiyonu - GELİŞTİRİLMİŞ
  static Future<void> sendTestNotification() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        print('=== TEST NOTIFICATION TOKEN ===');
        print(token);
        print('===============================');
        print('Firebase Console\'da bu token\'ı kullanın:');
        print('1. Firebase Console > Messaging');
        print('2. "Create your first campaign" tıklayın');
        print('3. "Send test message" seçin');
        print('4. Token\'ı yapıştırın ve "Test" tıklayın');

        // Test local notification
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'lgs_channel',
              'LGS Bildirimler',
              channelDescription: 'Test bildirimi',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            );

        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await _localNotifications.show(
          9999,
          'Test Bildirimi',
          'Bu bir test bildirimidir',
          notificationDetails,
        );

        print('Local test notification sent');
      }
    } catch (e) {
      print('Test notification error: $e');
    }
  }

  // Badge count güncelleme
  static Future<void> updateBadgeCount(int count) async {
    try {
      // iOS için badge count
      if (count > 0) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      print('Badge count updated: $count');
    } catch (e) {
      print('Error updating badge count: $e');
    }
  }

  // Unread notification sayısını al
  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      // Announcements sayısı
      var announcementCount = await _db
          .collection('users')
          .doc(userId)
          .collection('announcements')
          .where('isRead', isEqualTo: false)
          .get();

      // Notifications sayısı
      var notificationCount = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      int totalUnread =
          announcementCount.docs.length + notificationCount.docs.length;
      await updateBadgeCount(totalUnread);

      return totalUnread;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
}

// Background message handler (top-level function olmalı)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('=== BACKGROUND MESSAGE RECEIVED ===');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
  print('===================================');

  // Background'da da local notification göster
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'lgs_channel',
    'LGS Bildirimler',
    channelDescription: 'Background bildirim',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await FlutterLocalNotificationsPlugin().show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    message.notification?.title ?? message.data['title'] ?? '8B LGS Takip',
    message.notification?.body ?? message.data['body'] ?? 'Yeni bildirim',
    notificationDetails,
  );
}
