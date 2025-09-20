import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  @override
  _AdminAnnouncementScreenState createState() =>
      _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _announcementController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = false;
  bool _sendToAll = true;
  String? _selectedParent;
  List<Map<String, dynamic>> parents = [];

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  void _loadParents() async {
    try {
      var snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      List<Map<String, dynamic>> tempParents = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        var student = data['student'] as Map<String, dynamic>;
        tempParents.add({
          'id': doc.id,
          'studentName': student['name'] ?? '',
          'studentNo': student['schoolNo'] ?? '',
        });
      }

      setState(() {
        parents = tempParents;
      });
    } catch (e) {
      print('Error loading parents: $e');
    }
  }

  Future<void> _sendAnnouncementToAll(String title, String message) async {
    var usersSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    for (var userDoc in usersSnapshot.docs) {
      await userDoc.reference.collection('announcements').add({
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    // Global duyurular koleksiyonuna da ekle
    await _db.collection('announcements').add({
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'all',
    });
  }

  Future<void> _sendAnnouncementToUser(
    String parentId,
    String title,
    String message,
  ) async {
    await _db
        .collection('users')
        .doc(parentId)
        .collection('announcements')
        .add({
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

    // Global duyurular koleksiyonuna da ekle
    await _db.collection('announcements').add({
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'individual',
      'targetParent': parentId,
    });
  }

  void _sendAnnouncement() async {
    if (_titleController.text.isEmpty || _announcementController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Başlık ve mesaj boş bırakılamaz')),
      );
      return;
    }

    if (!_sendToAll && _selectedParent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lütfen bir veli seçin')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_sendToAll) {
        await _sendAnnouncementToAll(
          _titleController.text,
          _announcementController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duyuru tüm velilere gönderildi')),
        );
      } else {
        await _sendAnnouncementToUser(
          _selectedParent!,
          _titleController.text,
          _announcementController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duyuru seçili veliye gönderildi')),
        );
      }

      _titleController.clear();
      _announcementController.clear();
      setState(() {
        _selectedParent = null;
        _sendToAll = true;
      });
    } catch (e) {
      print('Error sending announcement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duyuru gönderilirken hata oluştu')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteAnnouncement(String docId) async {
    try {
      await _db.collection('announcements').doc(docId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duyuru silindi')));
    } catch (e) {
      print('Error deleting announcement: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Duyuru Yönetimi'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Duyuru Gönder',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Duyuru Başlığı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _announcementController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Duyuru Mesajı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: Text('Tüm Velilere'),
                            value: true,
                            groupValue: _sendToAll,
                            onChanged: (value) {
                              setState(() {
                                _sendToAll = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: Text('Seçili Veliye'),
                            value: false,
                            groupValue: _sendToAll,
                            onChanged: (value) {
                              setState(() {
                                _sendToAll = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_sendToAll) ...[
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Veli Seçin',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedParent,
                        items: parents.map((parent) {
                          return DropdownMenuItem<String>(
                            value: parent['id'],
                            child: Text(
                              '${parent['studentName']} (No: ${parent['studentNo']})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedParent = value;
                          });
                        },
                      ),
                    ],
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _sendAnnouncement,
                              icon: Icon(Icons.send),
                              label: Text('Duyuru Gönder'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Gönderilmiş Duyurular',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('announcements')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          var announcements = snapshot.data!.docs;

                          if (announcements.isEmpty) {
                            return Center(child: Text('Henüz duyuru yok'));
                          }

                          return ListView.builder(
                            itemCount: announcements.length,
                            itemBuilder: (context, index) {
                              var announcement = announcements[index];
                              var data =
                                  announcement.data() as Map<String, dynamic>;

                              return ListTile(
                                title: Text(
                                  data['title'] ?? 'Başlıksız',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['message'] ?? ''),
                                    SizedBox(height: 4),
                                    Text(
                                      '${data['type'] == 'all' ? 'Tüm Veliler' : 'Bireysel'} - ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().substring(0, 16) : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteAnnouncement(announcement.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Sil'),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
