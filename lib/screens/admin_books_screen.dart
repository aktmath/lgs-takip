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
        if (data['student'] != null) {
          var student = data['student'] as Map<String, dynamic>;
          tempParents.add({
            'id': doc.id,
            'studentName': student['name']?.toString() ?? 'İsimsiz',
            'studentNo': student['schoolNo']?.toString() ?? 'No Yok',
          });
        }
      }

      setState(() {
        parents = tempParents;
      });
    } catch (e) {
      print('Error loading parents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğrenci listesi yüklenirken hata: $e')),
      );
    }
  }

  void _addBookToStudent() async {
    // Null ve boş kontrolleri
    if (_bookTitleController.text.trim().isEmpty) {
      _showError('Kitap adı boş bırakılamaz');
      return;
    }

    if (_bookAuthorController.text.trim().isEmpty) {
      _showError('Yazar adı boş bırakılamaz');
      return;
    }

    if (_selectedParent == null || _selectedParent!.isEmpty) {
      _showError('Lütfen bir öğrenci seçin');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent!)
          .collection('books')
          .add({
            'title': _bookTitleController.text.trim(),
            'author': _bookAuthorController.text.trim(),
            'description': _descriptionController.text.trim(),
            'status': _bookStatus,
            'addedDate': FieldValue.serverTimestamp(),
            'finishedDate': _bookStatus == 'okudu'
                ? FieldValue.serverTimestamp()
                : null,
            'addedBy': 'admin',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kitap öğrenciye başarıyla eklendi'),
          backgroundColor: Colors.green,
        ),
      );

      // Form temizle
      _clearForm();
    } catch (e) {
      print('Error adding book: $e');
      _showError('Kitap eklenirken hata oluştu: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _clearForm() {
    _bookTitleController.clear();
    _bookAuthorController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedParent = null;
      _bookStatus = 'okuyor';
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      } else {
        updateData['finishedDate'] = null;
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
      _showError('Güncelleme başarısız: $e');
    }
  }

  // YENİ: Kitap düzenleme fonksiyonu
  Future<void> _editBook(
    String parentId,
    String bookId,
    Map<String, dynamic> currentBook,
  ) async {
    final titleController = TextEditingController(text: currentBook['title']);
    final authorController = TextEditingController(text: currentBook['author']);
    final descController = TextEditingController(
      text: currentBook['description'] ?? '',
    );
    String selectedStatus = currentBook['status'] ?? 'okuyor';

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kitap Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Kitap Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: authorController,
                decoration: InputDecoration(
                  labelText: 'Yazar',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Durum',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'okuyacak', child: Text('Okuyacak')),
                  DropdownMenuItem(value: 'okuyor', child: Text('Okuyor')),
                  DropdownMenuItem(value: 'okudu', child: Text('Okudu')),
                ],
                onChanged: (value) {
                  selectedStatus = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        Map<String, dynamic> updateData = {
          'title': titleController.text.trim(),
          'author': authorController.text.trim(),
          'description': descController.text.trim(),
          'status': selectedStatus,
        };

        if (selectedStatus == 'okudu' && currentBook['status'] != 'okudu') {
          updateData['finishedDate'] = FieldValue.serverTimestamp();
        } else if (selectedStatus != 'okudu') {
          updateData['finishedDate'] = null;
        }

        await _db
            .collection('users')
            .doc(parentId)
            .collection('books')
            .doc(bookId)
            .update(updateData);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kitap başarıyla güncellendi')));
      } catch (e) {
        print('Error updating book: $e');
        _showError('Güncelleme başarısız: $e');
      }
    }

    titleController.dispose();
    authorController.dispose();
    descController.dispose();
  }

  // YENİ: Kitap silme fonksiyonu
  Future<void> _deleteBook(
    String parentId,
    String bookId,
    String bookTitle,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kitap Sil'),
        content: Text(
          '\"$bookTitle\" kitabını silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db
            .collection('users')
            .doc(parentId)
            .collection('books')
            .doc(bookId)
            .delete();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kitap silindi')));
      } catch (e) {
        print('Error deleting book: $e');
        _showError('Silme işlemi başarısız: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getAllBooksWithParentInfo() async {
    List<Map<String, dynamic>> allBooks = [];

    try {
      for (var parent in parents) {
        var books = await _db
            .collection('users')
            .doc(parent['id'])
            .collection('books')
            .orderBy('addedDate', descending: true)
            .get();

        for (var book in books.docs) {
          var bookData = book.data();
          allBooks.add({
            'bookId': book.id,
            'parentId': parent['id'],
            'studentName': parent['studentName'] ?? 'İsimsiz',
            'studentNo': parent['studentNo'] ?? 'No Yok',
            'title': bookData['title']?.toString() ?? 'Başlıksız',
            'author': bookData['author']?.toString() ?? 'Bilinmiyor',
            'description': bookData['description']?.toString() ?? '',
            'status': bookData['status']?.toString() ?? 'okuyor',
            'addedDate': bookData['addedDate'],
            'finishedDate': bookData['finishedDate'],
            'fullData': bookData, // Düzenleme için tüm veri
          });
        }
      }
    } catch (e) {
      print('Error loading books: $e');
    }

    return allBooks;
  }

  Widget _buildBooksList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllBooksWithParentInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Henüz kitap eklenmemiş',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        var books = snapshot.data!;

        // Kitapları öğrenciye göre grupla
        Map<String, List<Map<String, dynamic>>> booksByStudent = {};
        for (var book in books) {
          String studentKey = '${book['studentName']} (${book['studentNo']})';
          if (!booksByStudent.containsKey(studentKey)) {
            booksByStudent[studentKey] = [];
          }
          booksByStudent[studentKey]!.add(book);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: booksByStudent.length,
          itemBuilder: (context, index) {
            String studentKey = booksByStudent.keys.elementAt(index);
            List<Map<String, dynamic>> studentBooks =
                booksByStudent[studentKey]!;

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  studentKey,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${studentBooks.length} kitap'),
                children: studentBooks.map((book) {
                  Color statusColor = book['status'] == 'okudu'
                      ? Colors.green
                      : book['status'] == 'okuyor'
                      ? Colors.blue
                      : Colors.orange;

                  return ListTile(
                    title: Text(book['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yazar: ${book['author']}'),
                        if (book['description'].isNotEmpty)
                          Text('Açıklama: ${book['description']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Durum dropdown
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: book['status'],
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
                                _updateBookStatus(
                                  book['parentId'],
                                  book['bookId'],
                                  newStatus,
                                );
                              }
                            },
                          ),
                        ),
                        // Düzenle/Sil menüsü
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editBook(
                                book['parentId'],
                                book['bookId'],
                                book['fullData'],
                              );
                            } else if (value == 'delete') {
                              _deleteBook(
                                book['parentId'],
                                book['bookId'],
                                book['title'],
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Düzenle'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Sil'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        value: parent['id']?.toString(),
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

  @override
  void dispose() {
    _bookTitleController.dispose();
    _bookAuthorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
