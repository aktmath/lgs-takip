import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm_services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class ParentNotificationsScreen extends StatefulWidget {
  final String parentUsername;

  const ParentNotificationsScreen({Key? key, required this.parentUsername})
    : super(key: key);

  @override
  _ParentNotificationsScreenState createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllNotifications();
  }

  Future<void> _fetchAllNotifications() async {
    try {
      // Duyuruları getir
      var announcementSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .get();

      // Bildirimleri getir
      var notificationSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> notifications = [];

      // Duyuruları ekle
      for (var doc in announcementSnapshot.docs) {
        var data = doc.data();
        notifications.add({
          'id': doc.id,
          'docRef': doc.reference,
          'type': 'announcement',
          'title': data['title'] ?? 'Duyuru',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
          'collection': 'announcements',
        });
      }

      // Bildirimleri ekle
      for (var doc in notificationSnapshot.docs) {
        var data = doc.data();
        notifications.add({
          'id': doc.id,
          'docRef': doc.reference,
          'type': data['type'] ?? 'info',
          'title': data['type'] == 'absence'
              ? 'Devamsızlık Bildirimi'
              : 'Bildirim',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
          'collection': 'notifications',
        });
      }

      // Zamana göre sırala
      notifications.sort((a, b) {
        var aTime = a['timestamp'] as Timestamp?;
        var bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        allNotifications = notifications;
        _isLoading = false;
      });

      // Badge count'u güncelle
      _updateBadgeCount();
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBadgeCount() async {
    try {
      int unreadCount = allNotifications.where((n) => !n['isRead']).length;

      // Flutter App Badger ile badge count güncelle
      if (unreadCount > 0) {
        await FlutterAppBadger.updateBadgeCount(unreadCount);
      } else {
        await FlutterAppBadger.removeBadge();
      }

      // FCM Services ile de güncelle
      await FCMServices.updateBadgeCount(unreadCount);

      print('Badge count updated: $unreadCount');
    } catch (e) {
      print('Error updating badge count: $e');
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (notification['isRead']) return;

    try {
      await notification['docRef'].update({'isRead': true});
      setState(() {
        notification['isRead'] = true;
      });

      // Badge count'u güncelle
      await _updateBadgeCount();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(
    Map<String, dynamic> notification,
    int index,
  ) async {
    try {
      await notification['docRef'].delete();
      setState(() {
        allNotifications.removeAt(index);
      });

      // Badge count'u güncelle
      await _updateBadgeCount();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bildirim silindi')));
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız')));
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      // Batch işlem için
      WriteBatch batch = _db.batch();

      for (var notification in allNotifications) {
        if (!notification['isRead']) {
          batch.update(notification['docRef'], {'isRead': true});
        }
      }

      await batch.commit();

      setState(() {
        for (var notification in allNotifications) {
          notification['isRead'] = true;
        }
      });

      // Badge'i temizle
      await FlutterAppBadger.removeBadge();
      await FCMServices.updateBadgeCount(0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm bildirimler okundu olarak işaretlendi')),
      );
    } catch (e) {
      print('Error marking all as read: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız')));
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih yok';
    var date = timestamp.toDate();
    var now = DateTime.now();
    var diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    Color cardColor;
    Color iconColor;
    IconData iconData;

    switch (notification['type']) {
      case 'absence':
        cardColor = Colors.red[50]!;
        iconColor = Colors.red[700]!;
        iconData = Icons.person_off;
        break;
      case 'announcement':
        cardColor = Colors.orange[50]!;
        iconColor = Colors.orange[700]!;
        iconData = Icons.campaign;
        break;
      default:
        cardColor = Colors.blue[50]!;
        iconColor = Colors.blue[700]!;
        iconData = Icons.notifications;
    }

    if (notification['isRead']) {
      cardColor = Colors.grey[100]!;
      iconColor = Colors.grey[600]!;
    }

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Bildirimi Sil'),
              content: Text('Bu bildirimi silmek istediğinizden emin misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Sil', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notification, index);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: cardColor,
        elevation: notification['isRead'] ? 1 : 3,
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          title: Text(
            notification['title'],
            style: TextStyle(
              fontWeight: notification['isRead']
                  ? FontWeight.normal
                  : FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                notification['message'],
                style: TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(notification['timestamp']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Spacer(),
                  if (!notification['isRead'])
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
          onTap: () => _markAsRead(notification),
          isThreeLine: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int unreadCount = allNotifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler ${unreadCount > 0 ? '($unreadCount)' : ''}'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Tümünü Okundu İşaretle',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'refresh') {
                _fetchAllNotifications();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Yenile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('Tümünü Okundu İşaretle'),
                  ],
                ),
                enabled: unreadCount > 0,
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (unreadCount > 0)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    color: Colors.blue[50],
                    child: Text(
                      '$unreadCount okunmamış bildirim',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: allNotifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Henüz bildirim yok',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchAllNotifications,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            itemCount: allNotifications.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationCard(
                                allNotifications[index],
                                index,
                              );
                            },
                          ),
                        ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Text(
                    'Bildirimleri silmek için sola kaydırın • Aşağı çekerek yenileyin',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    // App kapatıldığında badge'i güncelle
    _updateBadgeCount();
    super.dispose();
  }
}
