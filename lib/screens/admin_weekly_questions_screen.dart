import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWeeklyQuestionsScreen extends StatefulWidget {
  @override
  _AdminWeeklyQuestionsScreenState createState() =>
      _AdminWeeklyQuestionsScreenState();
}

class _AdminWeeklyQuestionsScreenState
    extends State<AdminWeeklyQuestionsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedParent;
  String? _selectedStudent;

  final Map<String, TextEditingController> _controllers = {
    'turkish': TextEditingController(),
    'math': TextEditingController(),
    'science': TextEditingController(),
    'english': TextEditingController(),
    'religion': TextEditingController(),
    'history': TextEditingController(),
  };

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

  void _saveWeeklyScores() async {
    if (_selectedParent == null || _selectedStudent == null) return;

    setState(() {
      _isLoading = true;
    });

    Map<String, int> scores = {};
    _controllers.forEach((subject, controller) {
      scores[subject] = int.tryParse(controller.text) ?? 0;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent)
          .collection('students')
          .doc(_selectedStudent)
          .collection('weekly_scores')
          .add(scores);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Haftalık sorular kaydedildi')));

      _controllers.forEach((key, controller) => controller.clear());
    } catch (e) {
      print('Error saving weekly scores: $e');
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
      appBar: AppBar(title: Text('Haftalık Sorular')),
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
            Expanded(
              child: ListView(
                children: _controllers.entries.map((entry) {
                  return TextField(
                    controller: entry.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          '${_capitalize(entry.key)} - Çözülen Soru Sayısı',
                    ),
                  );
                }).toList(),
              ),
            ),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveWeeklyScores,
                    child: Text('Kaydet'),
                  ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
