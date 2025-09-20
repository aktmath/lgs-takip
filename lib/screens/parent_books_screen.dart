import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentBooksScreen extends StatelessWidget {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getBooks() {
    return _db
        .collectionGroup('books')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Öğrenci Kitapları')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getBooks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          var books = snapshot.data!.docs;

          if (books.isEmpty) {
            return Center(child: Text('Henüz kitap eklenmemiş'));
          }

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              var book = books[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(book['title']),
                  subtitle: Text(
                    'Yazar: ${book['author']} - Tarih: ${book['date']}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
