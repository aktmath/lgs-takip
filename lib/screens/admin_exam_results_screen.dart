import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminExamResultsScreen extends StatefulWidget {
  @override
  _AdminExamResultsScreenState createState() => _AdminExamResultsScreenState();
}

class _AdminExamResultsScreenState extends State<AdminExamResultsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedParent;
  String? _selectedStudent;
  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();
  final TextEditingController _examScoreController = TextEditingController();
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

  void _addExam() async {
    if (_selectedParent == null ||
        _selectedStudent == null ||
        _examNameController.text.isEmpty ||
        _examDateController.text.isEmpty ||
        _examScoreController.text.isEmpty)
      return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent)
          .collection('students')
          .doc(_selectedStudent)
          .collection('exams')
          .add({
            'name': _examNameController.text,
            'date': _examDateController.text,
            'score': int.parse(_examScoreController.text),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sınav bilgisi eklendi')));

      _examNameController.clear();
      _examDateController.clear();
      _examScoreController.clear();
    } catch (e) {
      print('Error adding exam: $e');
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
      appBar: AppBar(title: Text('Öğrenci Sınav Bilgileri')),
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
            TextField(
              controller: _examNameController,
              decoration: InputDecoration(labelText: 'Sınav Adı'),
            ),
            TextField(
              controller: _examDateController,
              decoration: InputDecoration(labelText: 'Sınav Tarihi'),
            ),
            TextField(
              controller: _examScoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Puan'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _addExam, child: Text('Ekle')),
          ],
        ),
      ),
    );
  }
}
