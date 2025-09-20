import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamScreen extends StatefulWidget {
  @override
  _ExamScreenState createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();
  final TextEditingController _examScoreController = TextEditingController();
  bool _isLoading = false;

  void _addExam() async {
    if (_examNameController.text.isEmpty ||
        _examDateController.text.isEmpty ||
        _examScoreController.text.isEmpty)
      return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.collection('exams').add({
        'name': _examNameController.text,
        'date': _examDateController.text,
        'score': int.parse(_examScoreController.text),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _examNameController.clear();
      _examDateController.clear();
      _examScoreController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sınav eklendi')));
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
      appBar: AppBar(title: Text('Sınavlar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _examNameController,
              decoration: InputDecoration(labelText: 'Sınav Adı'),
            ),
            TextField(
              controller: _examDateController,
              decoration: InputDecoration(labelText: 'Tarih'),
            ),
            TextField(
              controller: _examScoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Puan'),
            ),
            SizedBox(height: 10),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _addExam, child: Text('Ekle')),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('exams')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var exam = docs[index];
                      return ListTile(
                        title: Text(exam['name']),
                        subtitle: Text(
                          '${exam['date']} - Puan: ${exam['score']}',
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
    );
  }
}
