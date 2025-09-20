import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBooksScreen extends StatefulWidget {
  @override
  _AdminBooksScreenState createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedParent;
  String? _selectedStudent;
  final TextEditingController _bookNameController = TextEditingController();
  final TextEditingController _bookAuthorController = TextEditingController();
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

  void _addBook() async {
    if (_selectedParent == null ||
        _selectedStudent == null ||
        _bookNameController.text.isEmpty ||
        _bookAuthorController.text.isEmpty)
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
          .collection('books')
          .add({
            'name': _bookNameController.text,
            'author': _bookAuthorController.text,
            'added_at': Timestamp.now(),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kitap eklendi')));

      _bookNameController.clear();
      _bookAuthorController.clear();
    } catch (e) {
      print('Error adding book: $e');
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
      appBar: AppBar(title: Text('Öğrenci Kitapları')),
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
              controller: _bookNameController,
              decoration: InputDecoration(labelText: 'Kitap Adı'),
            ),
            TextField(
              controller: _bookAuthorController,
              decoration: InputDecoration(labelText: 'Yazar'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _addBook,
                    child: Text('Kitap Ekle'),
                  ),
          ],
        ),
      ),
    );
  }
}
