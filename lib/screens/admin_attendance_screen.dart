import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAttendanceScreen extends StatefulWidget {
  @override
  _AdminAttendanceScreenState createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> students = [];
  Set<String> selectedStudents = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    try {
      var snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      List<Map<String, dynamic>> tempStudents = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        var student = data['student'] as Map<String, dynamic>;
        tempStudents.add({
          'parentId': doc.id,
          'name': student['name'] ?? '',
          'schoolNo': student['schoolNo'] ?? '',
        });
      }

      setState(() {
        students = tempStudents;
      });
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  Future<void> _sendAbsenceNotification(
    String parentId,
    String studentName,
  ) async {
    try {
      String today = DateTime.now().toIso8601String().substring(0, 10);

      // Aynı gün için devamsızlık kaydı var mı kontrol et
      var existingRecord = await _db
          .collection('users')
          .doc(parentId)
          .collection('attendance')
          .where('date', isEqualTo: today)
          .get();

      if (existingRecord.docs.isNotEmpty) {
        print(
          'Bu öğrenci için bugün zaten devamsızlık kaydı var: $studentName',
        );
        return; // Aynı gün için tekrar kayıt yapma
      }

      // Bildirim gönder - isRead alanı ile
      await _db.collection('users').doc(parentId).collection('notifications').add({
        'type': 'absence',
        'message':
            'Sayın veli, öğrenciniz $studentName bugün okula gelmemiştir. Bilginize.',
        'date': today,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // Okunmadı olarak işaretle
        'sentBy': 'admin',
      });

      // Devamsızlık kaydı ekle
      await _db.collection('users').doc(parentId).collection('attendance').add({
        'studentName': studentName,
        'date': today,
        'status': 'absent',
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });

      print('Devamsızlık bildirimi gönderildi: $studentName');
    } catch (e) {
      print('Error sending absence notification: $e');
      throw e;
    }
  }

  void _markSelectedAsAbsent() async {
    if (selectedStudents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lütfen en az bir öğrenci seçin')));
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Devamsızlık Bildirimi'),
        content: Text(
          'Seçili ${selectedStudents.length} öğrenci için devamsızlık bildirimi gönderilsin mi?\n\nBu işlem geri alınamaz ve velilere anlık bildirim gönderilecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      int successCount = 0;
      int skippedCount = 0;
      String today = DateTime.now().toIso8601String().substring(0, 10);

      for (String studentKey in selectedStudents) {
        var student = students.firstWhere(
          (s) => '${s['parentId']}_${s['name']}' == studentKey,
        );

        // Bugün için zaten kayıt var mı kontrol et
        var existingRecord = await _db
            .collection('users')
            .doc(student['parentId'])
            .collection('attendance')
            .where('date', isEqualTo: today)
            .get();

        if (existingRecord.docs.isNotEmpty) {
          skippedCount++;
          print('Atlandı (zaten kayıtlı): ${student['name']}');
          continue;
        }

        await _sendAbsenceNotification(student['parentId'], student['name']);
        successCount++;
      }

      String message =
          '$successCount öğrenci için devamsızlık bildirimi gönderildi';
      if (skippedCount > 0) {
        message += ' ($skippedCount öğrenci zaten kayıtlıydı)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        ),
      );

      setState(() {
        selectedStudents.clear();
      });
    } catch (e) {
      print('Error marking absent: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim gönderilirken hata oluştu')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearOldAttendanceRecords() async {
    try {
      // 30 gün öncesinden eski kayıtları sil
      String cutoffDate = DateTime.now()
          .subtract(Duration(days: 30))
          .toIso8601String()
          .substring(0, 10);

      var usersSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      int deletedCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        var oldRecords = await userDoc.reference
            .collection('attendance')
            .where('date', isLessThan: cutoffDate)
            .get();

        for (var record in oldRecords.docs) {
          await record.reference.delete();
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount eski devamsızlık kaydı temizlendi'),
          ),
        );
      }
    } catch (e) {
      print('Error clearing old records: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Devam Durumu'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (selectedStudents.isNotEmpty)
            IconButton(
              onPressed: _markSelectedAsAbsent,
              icon: Icon(Icons.notification_important),
              tooltip: 'Devamsızlık Bildir',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_old') {
                _clearOldAttendanceRecords();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_old',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('Eski Kayıtları Temizle'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedStudents.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.red.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedStudents.length} öğrenci seçildi - Devamsızlık bildirimi gönderilecek',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bugün: ${DateTime.now().toIso8601String().substring(0, 10)}\n'
                    'Aynı öğrenci için bugün zaten devamsızlık kaydı varsa tekrar gönderilmez.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Henüz öğrenci kaydedilmemiş'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var student = students[index];
                      String studentKey =
                          '${student['parentId']}_${student['name']}';
                      bool isSelected = selectedStudents.contains(studentKey);

                      return Card(
                        color: isSelected ? Colors.red.shade50 : null,
                        elevation: isSelected ? 4 : 1,
                        child: ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedStudents.add(studentKey);
                                } else {
                                  selectedStudents.remove(studentKey);
                                }
                              });
                            },
                            activeColor: Colors.red.shade700,
                          ),
                          title: Text(
                            student['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.red.shade700 : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Okul No: ${student['schoolNo']}'),
                              if (isSelected)
                                Text(
                                  'Devamsızlık bildirimi gönderilecek',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.person_off,
                                  color: Colors.red.shade700,
                                )
                              : Icon(
                                  Icons.person,
                                  color: Colors.green.shade700,
                                ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedStudents.remove(studentKey);
                              } else {
                                selectedStudents.add(studentKey);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (selectedStudents.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _markSelectedAsAbsent,
                      icon: Icon(Icons.send),
                      label: Text('Devamsızlık Bildirimi Gönder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (selectedStudents.length == students.length) {
              selectedStudents.clear();
            } else {
              selectedStudents = students
                  .map((s) => '${s['parentId']}_${s['name']}')
                  .toSet();
            }
          });
        },
        backgroundColor: Colors.red.shade600,
        child: Icon(
          selectedStudents.length == students.length
              ? Icons.clear_all
              : Icons.select_all,
          color: Colors.white,
        ),
        tooltip: selectedStudents.length == students.length
            ? 'Seçimi Temizle'
            : 'Tümünü Seç',
      ),
    );
  }
}
