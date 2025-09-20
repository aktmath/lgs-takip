import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentStudentScreen extends StatefulWidget {
  final String username; // Veli kullanıcı adı

  ParentStudentScreen({required this.username});

  @override
  _ParentStudentScreenState createState() => _ParentStudentScreenState();
}

class _ParentStudentScreenState extends State<ParentStudentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? studentInfo;
  List<Map<String, dynamic>> exams = [];
  List<Map<String, dynamic>> weeklyScores = [];
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentInfo();
    _fetchExams();
    _fetchWeeklyScores();
    _fetchBooks();
  }

  void _fetchStudentInfo() async {
    var doc = await _db.collection('users').doc(widget.username).get();
    if (doc.exists && doc.data()!.containsKey('student')) {
      setState(() {
        studentInfo = doc['student'];
      });
    }
  }

  void _fetchExams() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('exams')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            exams = snapshot.docs
                .map(
                  (doc) => {
                    'name': doc['name'],
                    'date': doc['date'],
                    'score': doc['score'],
                  },
                )
                .toList();
          });
        });
  }

  void _fetchWeeklyScores() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('weekly_scores')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            weeklyScores = snapshot.docs
                .map(
                  (doc) => {
                    'turkce': doc['turkce'],
                    'mat': doc['mat'],
                    'fen': doc['fen'],
                    'ing': doc['ing'],
                    'din': doc['din'],
                    'inkilap': doc['inkilap'],
                    'week': doc['week'],
                  },
                )
                .toList();
          });
        });
  }

  void _fetchBooks() {
    _db
        .collection('users')
        .doc(widget.username)
        .collection('books')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            books = snapshot.docs
                .map(
                  (doc) => {
                    'title': doc['title'],
                    'author': doc['author'],
                    'date': doc['date'],
                  },
                )
                .toList();
          });
        });
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Öğrenci Bilgileri')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (studentInfo != null)
              Text(
                'Öğrenci: ${studentInfo!['name']} ${studentInfo!['surname']} - No: ${studentInfo!['schoolNo']}',
                style: TextStyle(fontSize: 18),
              ),
            _buildSection(
              'Sınavlar',
              exams
                  .map(
                    (e) => Card(
                      child: ListTile(
                        title: Text(e['name']),
                        subtitle: Text('Tarih: ${e['date']}'),
                        trailing: Text('Puan: ${e['score']}'),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _buildSection(
              'Haftalık Soru Sayıları',
              weeklyScores
                  .map(
                    (w) => Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hafta: ${w['week']}'),
                            Text('Türkçe: ${w['turkce']}'),
                            Text('Matematik: ${w['mat']}'),
                            Text('Fen: ${w['fen']}'),
                            Text('İngilizce: ${w['ing']}'),
                            Text('Din: ${w['din']}'),
                            Text('İnkılap: ${w['inkilap']}'),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _buildSection(
              'Okunan Kitaplar',
              books
                  .map(
                    (b) => Card(
                      child: ListTile(
                        title: Text(b['title']),
                        subtitle: Text(
                          'Yazar: ${b['author']} - Tarih: ${b['date']}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
