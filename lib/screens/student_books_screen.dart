import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentBooksScreen extends StatefulWidget {
  final String parentUsername; // Veli kullanıcı adı

  StudentBooksScreen({required this.parentUsername});

  @override
  _StudentBooksScreenState createState() => _StudentBooksScreenState();
}

class _StudentBooksScreenState extends State<StudentBooksScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  void _fetchBooks() async {
    var studentDoc = await _db
        .collection('users')
        .doc(widget.parentUsername)
        .collection('students')
        .get();

    List<Map<String, dynamic>> tempBooks = [];
    for (var student in studentDoc.docs) {
      var booksSnapshot = await student.reference.collection('books').get();
      tempBooks.addAll(
        booksSnapshot.docs.map(
          (doc) => {
            'title': doc['title'],
            'author': doc['author'],
            'date': doc['date'],
            'studentName': student['name'],
          },
        ),
      );
    }

    setState(() {
      books = tempBooks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Öğrenci Kitapları')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: books.length,
        itemBuilder: (context, index) {
          var book = books[index];
          return Card(
            child: ListTile(
              title: Text(book['title']),
              subtitle: Text(
                '${book['author']} - ${book['studentName']} - ${book['date']}',
              ),
            ),
          );
        },
      ),
    );
  }
}
