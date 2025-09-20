import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBooksScreen extends StatefulWidget {
  @override
  _AdminBooksScreenState createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _bookTitleController = TextEditingController();
  final TextEditingController _bookAuthorController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedParent;
  String _bookStatus = 'okuyor'; // okuyor, okudu, okuyacak
  bool _isLoading = false;
  List<Map<String, dynamic>> parents = [];

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  void _loadParents() async {
    try {
      var snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      List<Map<String, dynamic>> tempParents = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        var student = data['student'] as Map<String, dynamic>;
        tempParents.add({
          'id': doc.id,
          'studentName': student['name'] ?? '',
          'studentNo': student['schoolNo'] ?? '',
        });
      }

      setState(() {
        parents = tempParents;
      });
    } catch (e) {
      print('Error loading parents: $e');
    }
  }

  void _addBookToStudent() async {
    if (_bookTitleController.text.isEmpty ||
        _bookAuthorController.text.isEmpty ||
        _selectedParent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen tüm alanları doldurun ve öğrenci seçin'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent)
          .collection('books')
          .add({
            'title': _bookTitleController.text.trim(),
            'author': _bookAuthorController.text.trim(),
            'description': _descriptionController.text.trim(),
            'status': _bookStatus, // okuyor, okudu, okuyacak
            'addedDate': FieldValue.serverTimestamp(),
            'finishedDate': _bookStatus == 'okudu'
                ? FieldValue.serverTimestamp()
                : null,
            'addedBy': 'admin',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kitap öğrenciye başarıyla eklendi')),
      );

      _bookTitleController.clear();
      _bookAuthorController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedParent = null;
        _bookStatus = 'okuyor';
      });
    } catch (e) {
      print('Error adding book: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kitap eklenirken hata oluştu')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateBookStatus(
    String parentId,
    String bookId,
    String newStatus,
  ) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};

      if (newStatus == 'okudu') {
        updateData['finishedDate'] = FieldValue.serverTimestamp();
      }

      await _db
          .collection('users')
          .doc(parentId)
          .collection('books')
          .doc(bookId)
          .update(updateData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kitap durumu güncellendi')));
    } catch (e) {
      print('Error updating book status: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Güncelleme başarısız')));
    }
  }

  Widget _buildBooksList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collectionGroup('books').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var books = snapshot.data!.docs;

        if (books.isEmpty) {
          return Center(child: Text('Henüz kitap eklenmemiş'));
        }

        // Kitapları öğrenciye göre grupla
        Map<String, List<QueryDocumentSnapshot>> booksByParent = {};
        for (var book in books) {
          String parentPath = book.reference.parent.parent!.id;
          if (!booksByParent.containsKey(parentPath)) {
            booksByParent[parentPath] = [];
          }
          booksByParent[parentPath]!.add(book);
        }

        return ListView.builder(
          itemCount: booksByParent.length,
          itemBuilder: (context, index) {
            String parentId = booksByParent.keys.elementAt(index);
            List<QueryDocumentSnapshot> parentBooks = booksByParent[parentId]!;

            // Parent bilgisini bul
            var parent = parents.firstWhere(
              (p) => p['id'] == parentId,
              orElse: () => {'studentName': 'Bilinmiyor', 'studentNo': ''},
            );

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ExpansionTile(
                title: Text(
                  '${parent['studentName']} (No: ${parent['studentNo']})',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${parentBooks.length} kitap'),
                children: parentBooks.map((book) {
                  var data = book.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title'] ?? 'Başlıksız'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yazar: ${data['author'] ?? 'Bilinmiyor'}'),
                        if (data['description'] != null &&
                            data['description'].isNotEmpty)
                          Text('${data['description']}'),
                      ],
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: data['status'] == 'okudu'
                            ? Colors.green.shade100
                            : data['status'] == 'okuyor'
                            ? Colors.blue.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: data['status'] ?? 'okuyor',
                        underline: SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 'okuyacak',
                            child: Text('Okuyacak'),
                          ),
                          DropdownMenuItem(
                            value: 'okuyor',
                            child: Text('Okuyor'),
                          ),
                          DropdownMenuItem(
                            value: 'okudu',
                            child: Text('Okudu'),
                          ),
                        ],
                        onChanged: (newStatus) {
                          if (newStatus != null) {
                            _updateBookStatus(parentId, book.id, newStatus);
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Öğrenci Kitap Yönetimi'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Öğrenciye Kitap Ekle',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Öğrenci Seçin',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedParent,
                    items: parents.map((parent) {
                      return DropdownMenuItem<String>(
                        value: parent['id'],
                        child: Text(
                          '${parent['studentName']} (No: ${parent['studentNo']})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedParent = value;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _bookTitleController,
                    decoration: InputDecoration(
                      labelText: 'Kitap Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _bookAuthorController,
                    decoration: InputDecoration(
                      labelText: 'Yazar',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Açıklama (Opsiyonel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Kitap Durumu',
                      border: OutlineInputBorder(),
                    ),
                    value: _bookStatus,
                    items: [
                      DropdownMenuItem(
                        value: 'okuyacak',
                        child: Text('Okuyacak'),
                      ),
                      DropdownMenuItem(value: 'okuyor', child: Text('Okuyor')),
                      DropdownMenuItem(value: 'okudu', child: Text('Okudu')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _bookStatus = value!;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _addBookToStudent,
                            icon: Icon(Icons.add),
                            label: Text('Kitap Ekle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBooksList()),
        ],
      ),
    );
  }
}
