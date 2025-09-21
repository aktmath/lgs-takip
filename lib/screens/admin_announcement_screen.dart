import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm_services.dart';

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
        var student = data['student'] as Map<String, dynamic>?;
        if (student != null) {
          tempParents.add({
            'id': doc.id,
            'studentName': student['name'] ?? 'İsimsiz',
            'studentNo': student['schoolNo'] ?? 'No Yok',
            'fcmToken': data['fcmToken'], // FCM token'ı ekle
          });
        }
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

    int sentCount = 0;
    int fcmSentCount = 0;

    for (var userDoc in usersSnapshot.docs) {
      var userData = userDoc.data();

      // Firestore'a kaydet
      await userDoc.reference.collection('announcements').add({
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'sentBy': 'admin',
        'priority': 'normal',
      });
      sentCount++;

      // FCM bildirimi gönder
      String? fcmToken = userData['fcmToken'] as String?;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await FCMServices.sendNotificationViaFirestore(
            userId: userDoc.id,
            title: title,
            body: message,
            type: 'announcement',
          );
          fcmSentCount++;
          print('FCM notification sent to: ${userDoc.id}');
        } catch (e) {
          print('Error sending FCM to ${userDoc.id}: $e');
        }
      } else {
        print('No FCM token for user: ${userDoc.id}');
      }
    }

    // Global duyurular koleksiyonuna da ekle
    await _db.collection('announcements').add({
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'all',
      'sentCount': sentCount,
      'fcmSentCount': fcmSentCount,
      'sentBy': 'admin',
    });

    print(
      'Duyuru $sentCount veliye gönderildi, $fcmSentCount FCM bildirimi gönderildi',
    );
  }

  Future<void> _sendAnnouncementToUser(
    String parentId,
    String title,
    String message,
  ) async {
    // Firestore'a kaydet
    await _db
        .collection('users')
        .doc(parentId)
        .collection('announcements')
        .add({
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'sentBy': 'admin',
          'priority': 'normal',
        });

    // FCM bildirimi gönder
    try {
      var userDoc = await _db.collection('users').doc(parentId).get();
      var userData = userDoc.data();
      String? fcmToken = userData?['fcmToken'] as String?;

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FCMServices.sendNotificationViaFirestore(
          userId: parentId,
          title: title,
          body: message,
          type: 'announcement',
        );
        print('FCM notification sent to: $parentId');
      } else {
        print('No FCM token for user: $parentId');
      }
    } catch (e) {
      print('Error sending FCM to $parentId: $e');
    }

    // Global duyurular koleksiyonuna da ekle
    await _db.collection('announcements').add({
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'individual',
      'targetParent': parentId,
      'sentBy': 'admin',
    });

    print('Bireysel duyuru gönderildi: $parentId');
  }

  void _sendAnnouncement() async {
    if (_titleController.text.trim().isEmpty ||
        _announcementController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Başlık ve mesaj boş bırakılamaz')),
      );
      return;
    }

    if (!_sendToAll && (_selectedParent == null || _selectedParent!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lütfen bir veli seçin')));
      return;
    }

    // Onay iletişim kutusu
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duyuru Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Başlık: ${_titleController.text.trim()}'),
            SizedBox(height: 8),
            Text('Mesaj: ${_announcementController.text.trim()}'),
            SizedBox(height: 8),
            Text(
              _sendToAll
                  ? 'Tüm velilere gönderilecek (${parents.length} kişi)'
                  : 'Seçili veliye gönderilecek',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Push bildirim de gönderilecek',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Gönder'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_sendToAll) {
        await _sendAnnouncementToAll(
          _titleController.text.trim(),
          _announcementController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duyuru tüm velilere gönderildi (Push bildirim dahil)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _sendAnnouncementToUser(
          _selectedParent!,
          _titleController.text.trim(),
          _announcementController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duyuru seçili veliye gönderildi (Push bildirim dahil)',
            ),
            backgroundColor: Colors.green,
          ),
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

  // Test bildirimi gönder
  void _sendTestNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FCMServices.sendTestNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test bildirimi gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error sending test notification: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Test bildirimi gönderilemedi')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteAnnouncement(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duyuru Sil'),
        content: Text(
          'Bu duyuruyu silmek istediğinizden emin misiniz?\n\nNot: Bu işlem sadece genel kayıttan siler, velilere gönderilen duyuruları silmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih yok';
    var date = timestamp.toDate();
    var now = DateTime.now();
    var diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Duyuru Yönetimi'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _sendTestNotification,
            icon: Icon(Icons.send),
            tooltip: 'Test Bildirimi Gönder',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_old') {
                _clearOldAnnouncements();
              } else if (value == 'test_fcm') {
                _sendTestNotification();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'test_fcm',
                child: Row(
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 8),
                    Text('Test FCM Bildirimi'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_old',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('Eski Duyuruları Temizle'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Yeni duyuru gönderme formu
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Duyuru Gönder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Duyuru Başlığı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    maxLength: 100,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _announcementController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Duyuru Mesajı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                      hintText: 'Duyuru metninizi buraya yazın...',
                    ),
                    maxLength: 500,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('Tüm Velilere'),
                          subtitle: Text('${parents.length} veli'),
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
                          subtitle: Text('Bireysel gönderim'),
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
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duyuru hem uygulama içinde hem de push bildirim olarak gönderilecek',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

          // Gönderilmiş duyurular listesi
          Expanded(
            child: Card(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        if (snapshot.hasError) {
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        var announcements = snapshot.data!.docs;

                        if (announcements.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.campaign,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text('Henüz duyuru yok'),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          itemCount: announcements.length,
                          itemBuilder: (context, index) {
                            var announcement = announcements[index];
                            var data =
                                announcement.data() as Map<String, dynamic>?;

                            if (data == null) {
                              return SizedBox(); // Boş data durumu
                            }

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: data['type'] == 'all'
                                        ? Colors.orange[100]
                                        : Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    data['type'] == 'all'
                                        ? Icons.campaign
                                        : Icons.person,
                                    color: data['type'] == 'all'
                                        ? Colors.orange[700]
                                        : Colors.blue[700],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  data['title']?.toString() ?? 'Başlıksız',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['message']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: data['type'] == 'all'
                                                ? Colors.orange[200]
                                                : Colors.blue[200],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            data['type'] == 'all'
                                                ? 'Tüm Veliler'
                                                : 'Bireysel',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          _formatDate(data['timestamp']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (data['sentCount'] != null) ...[
                                          SizedBox(width: 8),
                                          Text(
                                            '(${data['sentCount']} kişi)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                        if (data['fcmSentCount'] != null) ...[
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.notifications_active,
                                            size: 12,
                                            color: Colors.green.shade600,
                                          ),
                                          Text(
                                            '${data['fcmSentCount']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
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
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Sil'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
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
          ),
        ],
      ),
    );
  }

  Future<void> _clearOldAnnouncements() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eski Duyuruları Temizle'),
        content: Text(
          '30 günden eski duyurular silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: 30));

      var oldAnnouncements = await _db
          .collection('announcements')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      int deletedCount = 0;
      for (var doc in oldAnnouncements.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deletedCount eski duyuru temizlendi')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Temizlenecek eski duyuru bulunamadı')),
        );
      }
    } catch (e) {
      print('Error clearing old announcements: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Temizleme işlemi başarısız')));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _announcementController.dispose();
    super.dispose();
  }
}
