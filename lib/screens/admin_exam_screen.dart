import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminExamScreen extends StatefulWidget {
  @override
  _AdminExamScreenState createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _selectedParent;
  String? _selectedStudent;

  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();

  bool _isLoading = false;

  // Dersler ve her ders için Doğru/Yanlış/Boş controllerları
  final Map<String, Map<String, TextEditingController>> _dersControllers = {
    'turkce': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
    'matematik': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
    'fen': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
    'inkilap': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
    'din': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
    'ingilizce': {
      'dogru': TextEditingController(),
      'yanlis': TextEditingController(),
      'bos': TextEditingController(),
    },
  };

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

  void _saveExam({String? docId}) async {
    if (_selectedParent == null || _selectedStudent == null) return;
    if (_examNameController.text.isEmpty || _examDateController.text.isEmpty)
      return;

    setState(() => _isLoading = true);

    Map<String, Map<String, int>> dersData = {};

    _dersControllers.forEach((ders, ctrl) {
      dersData[ders] = {
        'dogru': int.tryParse(ctrl['dogru']!.text) ?? 0,
        'yanlis': int.tryParse(ctrl['yanlis']!.text) ?? 0,
        'bos': int.tryParse(ctrl['bos']!.text) ?? 0,
      };
    });

    try {
      var examsRef = _db
          .collection('users')
          .doc(_selectedParent)
          .collection('students')
          .doc(_selectedStudent)
          .collection('exams');

      if (docId == null) {
        await examsRef.add({
          'name': _examNameController.text,
          'date': _examDateController.text,
          ...dersData,
        });
      } else {
        await examsRef.doc(docId).update({
          'name': _examNameController.text,
          'date': _examDateController.text,
          ...dersData,
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deneme sınavı kaydedildi')));

      _examNameController.clear();
      _examDateController.clear();
      _dersControllers.forEach((_, dersCtrl) {
        dersCtrl.forEach((__, c) => c.clear());
      });
    } catch (e) {
      print('Error saving exam: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir hata oluştu')));
    }

    setState(() => _isLoading = false);
  }

  Widget _buildDersInput(
    String dersAdi,
    Map<String, TextEditingController> ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dersAdi, style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl['dogru'],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Doğru'),
              ),
            ),
            Expanded(
              child: TextField(
                controller: ctrl['yanlis'],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Yanlış'),
              ),
            ),
            Expanded(
              child: TextField(
                controller: ctrl['bos'],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Boş'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deneme Sınavı Ekle')),
      body: Padding(
        padding: EdgeInsets.all(16),
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
              decoration: InputDecoration(labelText: 'Deneme Adı'),
            ),
            TextField(
              controller: _examDateController,
              decoration: InputDecoration(labelText: 'Tarih'),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: _dersControllers.entries
                    .map(
                      (entry) =>
                          _buildDersInput(_capitalize(entry.key), entry.value),
                    )
                    .toList(),
              ),
            ),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _saveExam(),
                    child: Text('Kaydet'),
                  ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
