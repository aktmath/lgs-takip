import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentAnnouncementsScreen extends StatelessWidget {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getAnnouncements() {
    return _db
        .collection('announcements')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Duyurular')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAnnouncements(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          var announcements = snapshot.data!.docs;

          if (announcements.isEmpty) {
            return Center(child: Text('Henüz duyuru yok'));
          }

          return ListView.builder(
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              var ann = announcements[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(ann['title']),
                  subtitle: Text(ann['content']),
                  trailing: Text(ann['date']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
