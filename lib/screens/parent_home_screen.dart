import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_services.dart';

class ParentHomeScreen extends StatefulWidget {
  final String username; // Veli kullanıcı adı

  const ParentHomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  _ParentHomeScreenState createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _fetchNotifications();
  }

  void _fetchAnnouncements() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            announcements = snapshot.docs
                .map(
                  (doc) => {
                    'message': doc['message'],
                    'timestamp': doc['timestamp'],
                  },
                )
                .toList();
          });
        });
  }

  void _fetchNotifications() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            notifications = snapshot.docs
                .map(
                  (doc) => {
                    'type': doc['type'],
                    'message': doc['message'],
                    'timestamp': doc['timestamp'],
                  },
                )
                .toList();
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Veli Ekranı')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duyurular',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...announcements.map(
              (a) => Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(a['message']),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Bildirimler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...notifications.map(
              (n) => Card(
                color: n['type'] == 'absence'
                    ? Colors.red[100]
                    : Colors.grey[200],
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(n['message']),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
