import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BooksScreen extends StatefulWidget {
  @override
  _BooksScreenState createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _bookTitleController = TextEditingController();
  final TextEditingController _bookAuthorController = TextEditingController();
  bool _isLoading = false;

  void _addBook() async {
    if (_bookTitleController.text.isEmpty || _bookAuthorController.text.isEmpty)
      return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.collection('books').add({
        'title': _bookTitleController.text,
        'author': _bookAuthorController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _bookTitleController.clear();
      _bookAuthorController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kitap eklendi')));
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
      appBar: AppBar(title: Text('Kitaplar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _bookTitleController,
              decoration: InputDecoration(labelText: 'Kitap Adı'),
            ),
            TextField(
              controller: _bookAuthorController,
              decoration: InputDecoration(labelText: 'Yazar'),
            ),
            SizedBox(height: 10),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _addBook, child: Text('Ekle')),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('books')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var book = docs[index];
                      return ListTile(
                        title: Text(book['title']),
                        subtitle: Text(book['author']),
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
