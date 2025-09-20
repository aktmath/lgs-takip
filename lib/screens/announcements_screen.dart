import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementsScreen extends StatefulWidget {
  @override
  _AnnouncementsScreenState createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _announcementController = TextEditingController();
  bool _isLoading = false;

  void _addAnnouncement() async {
    if (_announcementController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.collection('announcements').add({
        'text': _announcementController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _announcementController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duyuru eklendi')));
    } catch (e) {
      print('Error adding announcement: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir hata oluştu')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Duyurular')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _announcementController,
              decoration: InputDecoration(labelText: 'Yeni Duyuru'),
            ),
            SizedBox(height: 10),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _addAnnouncement,
                    child: Text('Ekle'),
                  ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('announcements')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var announcement = docs[index];
                      return ListTile(
                        title: Text(announcement['text']),
                        subtitle: Text(
                          announcement['timestamp'] != null
                              ? announcement['timestamp'].toDate().toString()
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
