import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAttendanceScreen extends StatefulWidget {
  @override
  _AdminAttendanceScreenState createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedParent;
  String? _selectedStudent;
  bool _isLoading = false;

  Future<List<String>> _getParents() async {
    var snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<String>> _getStudents(String parentId) async {
    var doc = await _db.collection('users').doc(parentId).get();
    if (!doc.exists) return [];
    var student = doc['student'];
    return [student['name']];
  }

  void _markAbsent() async {
    if (_selectedParent == null || _selectedStudent == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent)
          .collection('students')
          .doc(_selectedStudent)
          .collection('attendance')
          .add({'date': Timestamp.now(), 'status': 'absent'});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Devamsızlık kaydedildi')));
    } catch (e) {
      print('Error marking attendance: $e');
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
      appBar: AppBar(title: Text('Öğrenci Devam Durumu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FutureBuilder<List<String>>(
              future: _getParents(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                var parents = snapshot.data!;
                return DropdownButton<String>(
                  hint: Text('Veli Seç'),
                  value: _selectedParent,
                  items: parents
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) async {
                    _selectedParent = val;
                    var students = await _getStudents(val!);
                    setState(() {
                      _selectedStudent = students.isNotEmpty
                          ? students[0]
                          : null;
                    });
                  },
                );
              },
            ),
            if (_selectedStudent != null) Text('Öğrenci: $_selectedStudent'),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _markAbsent,
                    child: Text('Okula Gelmedi'),
                  ),
          ],
        ),
      ),
    );
  }
}
