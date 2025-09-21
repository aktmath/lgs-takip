import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent_exam_results_screen.dart';
import 'parent_subject_exam_screen.dart'; // YENİ EKLENEN
import 'parent_books_screen.dart';
import 'ai_analysis_screen.dart';
import 'parent_weekly_entry_screen.dart';
import 'parent_notifications_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import '../services/fcm_services.dart'; // YENİ EKLENEN

class ParentHomeScreen extends StatefulWidget {
  final String username;

  const ParentHomeScreen({super.key, required this.username});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? studentInfo;
  List<Map<String, dynamic>> notifications = [];
  int unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStudentInfo();
    _fetchNotifications();
    _listenToNotificationChanges();
    _saveUserToken(); // YENİ EKLENEN
  }

  // YENİ EKLENEN METHOD
  void _saveUserToken() async {
    try {
      await FCMServices.saveTokenToFirestore(widget.username);
      print('FCM Token saved for user: ${widget.username}');
    } catch (e) {
      print('Error saving user token: $e');
    }
  }

  void _fetchStudentInfo() async {
    try {
      var doc = await _db.collection('users').doc(widget.username).get();
      if (doc.exists && doc.data()!.containsKey('student')) {
        setState(() {
          studentInfo = doc['student'];
        });
      }
    } catch (e) {
      print('Error fetching student info: $e');
    }
  }

  void _fetchNotifications() async {
    try {
      // DuyurularÄ± getir
      var announcementSnapshot = await _db
          .collection('users')
          .doc(widget.username)
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // Bildirimleri getir
      var notificationSnapshot = await _db
          .collection('users')
          .doc(widget.username)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> allNotifications = [];

      // DuyurularÄ± ekle
      for (var doc in announcementSnapshot.docs) {
        var data = doc.data();
        allNotifications.add({
          'id': doc.id,
          'type': 'announcement',
          'title': data['title'] ?? 'Duyuru',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
        });
      }

      // Bildirimleri ekle
      for (var doc in notificationSnapshot.docs) {
        var data = doc.data();
        allNotifications.add({
          'id': doc.id,
          'type': data['type'] ?? 'info',
          'title': data['type'] == 'absence'
              ? 'Devamsızlık Bildirimi'
              : data['type'] == 'subject_exam'
              ? 'Ders Denemesi Sonucu'
              : data['type'] == 'subject_exam_absent'
              ? 'Ders Denemesi Devamsızlık'
              : 'Bildirim',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
        });
      }

      // Zamana gÃ¶re sÄ±rala
      allNotifications.sort((a, b) {
        var aTime = a['timestamp'] as Timestamp?;
        var bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        notifications = allNotifications;
        unreadNotificationCount = allNotifications
            .where((n) => !n['isRead'])
            .length;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void _listenToNotificationChanges() {
    // Duyurular iÃ§in listener
    _db
        .collection('users')
        .doc(widget.username)
        .collection('announcements')
        .snapshots()
        .listen((snapshot) {
          _fetchNotifications();
        });

    // Bildirimler iÃ§in listener
    _db
        .collection('users')
        .doc(widget.username)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
          _fetchNotifications();
        });
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickNotification() {
    if (notifications.isEmpty) return SizedBox();

    var latestNotification = notifications.first;
    if (latestNotification['isRead']) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ParentNotificationsScreen(parentUsername: widget.username),
              ),
            ).then((_) => _fetchNotifications());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: latestNotification['type'] == 'absence'
                        ? Colors.red[100]
                        : latestNotification['type'] == 'announcement'
                        ? Colors.orange[100]
                        : latestNotification['type'] == 'subject_exam'
                        ? Colors.blue[100]
                        : latestNotification['type'] == 'subject_exam_absent'
                        ? Colors.red[100]
                        : Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    latestNotification['type'] == 'absence'
                        ? Icons.person_off
                        : latestNotification['type'] == 'announcement'
                        ? Icons.campaign
                        : latestNotification['type'] == 'subject_exam'
                        ? Icons.school
                        : latestNotification['type'] == 'subject_exam_absent'
                        ? Icons.school_outlined
                        : Icons.notifications,
                    color: latestNotification['type'] == 'absence'
                        ? Colors.red[700]
                        : latestNotification['type'] == 'announcement'
                        ? Colors.orange[700]
                        : latestNotification['type'] == 'subject_exam'
                        ? Colors.blue[700]
                        : latestNotification['type'] == 'subject_exam_absent'
                        ? Colors.red[700]
                        : Colors.blue[700],
                    size: 22,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestNotification['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        latestNotification['message'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BAİHL LGS Takip'),
        backgroundColor: Color(0xFF2E8B57),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Bildirim ikonu
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParentNotificationsScreen(
                        parentUsername: widget.username,
                      ),
                    ),
                  ).then((_) => _fetchNotifications());
                },
                icon: Icon(Icons.notifications_outlined, size: 26),
                tooltip: 'Bildirimler',
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      unreadNotificationCount > 99
                          ? '99+'
                          : '$unreadNotificationCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePasswordScreen(
                    username: widget.username,
                    isAdmin: false,
                  ),
                ),
              );
            },
            icon: Icon(Icons.security_outlined),
            tooltip: 'Şifre Değiştir',
          ),
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            icon: Icon(Icons.logout_outlined, size: 24),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E8B57), // Deniz yeşili
              Color(0xFF20B2AA), // Açık deniz yeşili
              Color(0xFF4682B4), // Çelik mavisi
            ],
          ),
          // MEB logosu arka planda - burada assets/images/meb_logo.png dosyasÄ± olmalÄ±
          image: DecorationImage(
            image: AssetImage('assets/images/meb_logo.png'),
            alignment: Alignment.bottomCenter,
            opacity: 0.08, // Çok Şeffaf
            fit: BoxFit.contain,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Öğrenci bilgileri - iyileştirilmiş
              if (studentInfo != null) ...[
                Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2E8B57).withOpacity(0.2),
                              Color(0xFF4682B4).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.school,
                          color: Color(0xFF2E8B57),
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentInfo!['name'] ?? 'Ã–ÄŸrenci',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Okul No: ${studentInfo!['schoolNo'] ?? 'Bilinmiyor'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Son bildirim hızlı gösterimi
              _buildQuickNotification(),

              // Menü grid - iyileştirilmiş padding ve YENİ MENÜ EKLENDİ
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.0,
                    children: [
                      _buildMenuCard(
                        'Genel Denemeler',
                        'LGS takip ve analiz',
                        Icons.quiz_outlined,
                        Color(0xFF8E44AD),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParentExamResultsScreen(
                              parentUsername: widget.username,
                            ),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        'Ders Denemeleri', // YENİ EKLENEN
                        'Ders bazı deneme takibi',
                        Icons.school_outlined,
                        Color(0xFF2980B9),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParentSubjectExamScreen(
                              parentUsername: widget.username,
                            ),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        'Kitap Listesi',
                        'Okuma takibi',
                        Icons.menu_book_outlined,
                        Color(0xFF16A085),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParentBooksScreen(
                              parentUsername: widget.username,
                            ),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        'AI Analiz',
                        'Yapay zeka analizi',
                        Icons.psychology_outlined,
                        Color(0xFF9B59B6),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AIAnalysisScreen(
                              parentUsername: widget.username,
                            ),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        'Haftalık Sorular',
                        'Soru sayısı giriniz',
                        Icons.assignment_outlined,
                        Color(0xFFE67E22),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ParentWeeklyEntryScreen(
                              parentUsername: widget.username,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }
}
