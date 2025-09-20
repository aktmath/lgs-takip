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
      // Bildirim gönder
      await _db.collection('users').doc(parentId).collection('notifications').add({
        'type': 'absence',
        'message':
            'Sayın veli, öğrenciniz $studentName bugün okula gelmemiştir. Bilginize.',
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Devamsızlık kaydı ekle
      await _db.collection('users').doc(parentId).collection('attendance').add({
        'studentName': studentName,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'absent',
        'timestamp': FieldValue.serverTimestamp(),
      });
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
          'Seçili ${selectedStudents.length} öğrenci için devamsızlık bildirimi gönderilsin mi?',
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
      int successCount = 0;
      for (String studentKey in selectedStudents) {
        var student = students.firstWhere(
          (s) => '${s['parentId']}_${s['name']}' == studentKey,
        );
        await _sendAbsenceNotification(student['parentId'], student['name']);
        successCount++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount öğrenci için devamsızlık bildirimi gönderildi',
          ),
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
        ],
      ),
      body: Column(
        children: [
          if (selectedStudents.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: EdgeInsets.all(16),
              child: Text(
                '${selectedStudents.length} öğrenci seçildi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
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
                          ),
                          title: Text(
                            student['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.red.shade700 : null,
                            ),
                          ),
                          subtitle: Text('Okul No: ${student['schoolNo']}'),
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
