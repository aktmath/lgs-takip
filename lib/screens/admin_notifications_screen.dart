import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationsScreen extends StatefulWidget {
  @override
  _AdminNotificationsScreenState createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _notificationController = TextEditingController();
  bool _isLoading = false;

  void _sendNotification() async {
    if (_notificationController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.collection('notifications').add({
        'message': _notificationController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim tüm velilere gönderildi')),
      );
      _notificationController.clear();
    } catch (e) {
      print('Error sending notification: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bildirim gönderilemedi')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bildirimler')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _notificationController,
              decoration: InputDecoration(labelText: 'Bildirim Mesajı'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendNotification,
                    child: Text('Gönder'),
                  ),
            SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  var notifications = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      var notif = notifications[index];
                      return ListTile(
                        title: Text(notif['message']),
                        subtitle: Text(
                          notif['timestamp'] != null
                              ? notif['timestamp'].toDate().toString()
                              : '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
