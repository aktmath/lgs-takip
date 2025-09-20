import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentNotificationsScreen extends StatefulWidget {
  final String username; // Veli kullanıcı adı

  ParentNotificationsScreen({required this.username});

  @override
  _ParentNotificationsScreenState createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
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
      appBar: AppBar(title: Text('Bildirimler')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          var n = notifications[index];
          return Card(
            color: n['type'] == 'absence' ? Colors.red[100] : Colors.grey[200],
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(n['message']),
            ),
          );
        },
      ),
    );
  }
}
