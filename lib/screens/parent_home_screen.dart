import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent_exam_results_screen.dart';
import 'parent_books_screen.dart';
import 'ai_analysis_screen.dart';
import 'parent_weekly_entry_screen.dart';
import 'login_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  final String username;

  const ParentHomeScreen({super.key, required this.username});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? studentInfo;
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentInfo();
    _fetchAnnouncements();
    _fetchNotifications();
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

  void _fetchAnnouncements() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            announcements = snapshot.docs.map((doc) {
              var data = doc.data();
              return {
                'title': data['title'] ?? 'Duyuru',
                'message': data['message'] ?? '',
                'timestamp': data['timestamp'],
              };
            }).toList();
          });
        });
  }

  void _fetchNotifications() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            notifications = snapshot.docs.map((doc) {
              var data = doc.data();
              return {
                'type': data['type'] ?? 'info',
                'message': data['message'] ?? '',
                'timestamp': data['timestamp'],
              };
            }).toList();
          });
        });
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Son Duyurular',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (announcements.isEmpty)
              Text('Henüz duyuru yok', style: TextStyle(color: Colors.grey))
            else
              ...announcements.take(2).map((announcement) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: Colors.orange, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          announcement['message'],
                          style: TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Son Bildirimler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (notifications.isEmpty)
              Text('Henüz bildirim yok', style: TextStyle(color: Colors.grey))
            else
              ...notifications.take(2).map((notification) {
                Color bgColor = notification['type'] == 'absence'
                    ? Colors.red[50]!
                    : Colors.blue[50]!;
                Color borderColor = notification['type'] == 'absence'
                    ? Colors.red
                    : Colors.blue;

                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: borderColor, width: 4),
                      ),
                    ),
                    child: Text(
                      notification['message'],
                      style: TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BAİHL LGS Takip - Veli Paneli'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            icon: Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[500]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (studentInfo != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          radius: 24,
                          child: Icon(Icons.school, color: Colors.blue[700]),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentInfo!['name'] ?? 'Öğrenci',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Okul No: ${studentInfo!['schoolNo'] ?? 'Bilinmiyor'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Menü kartları - daha büyük alan
                        Container(
                          height: 280, // Yüksekliği artırdık
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0, // Kare şeklinde
                            children: [
                              _buildMenuCard(
                                'Deneme Sonuçları',
                                'LGS takip',
                                Icons.quiz,
                                Colors.purple,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ParentExamResultsScreen(
                                          parentUsername: widget.username,
                                        ),
                                  ),
                                ),
                              ),
                              _buildMenuCard(
                                'Kitaplar',
                                'Okuma listesi',
                                Icons.book,
                                Colors.teal,
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
                                Icons.psychology,
                                Colors.purple,
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
                                'Soru girişi',
                                Icons.assignment,
                                Colors.orange,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ParentWeeklyEntryScreen(
                                          parentUsername: widget.username,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        _buildAnnouncementCard(),
                        SizedBox(height: 12),
                        _buildNotificationCard(),
                        SizedBox(height: 20), // Alt padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
