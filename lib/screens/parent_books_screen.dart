import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentBooksScreen extends StatefulWidget {
  final String parentUsername;

  const ParentBooksScreen({super.key, required this.parentUsername});

  @override
  State<ParentBooksScreen> createState() => _ParentBooksScreenState();
}

class _ParentBooksScreenState extends State<ParentBooksScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih yok';
    var date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    Color statusColor;
    String statusText;

    switch (book['status']) {
      case 'okudu':
        statusColor = Colors.green;
        statusText = 'Okudu';
        break;
      case 'okuyor':
        statusColor = Colors.blue;
        statusText = 'Okuyor';
        break;
      case 'okuyacak':
        statusColor = Colors.orange;
        statusText = 'Okuyacak';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Bilinmiyor';
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            book['status'] == 'okudu' ? Icons.check_circle : Icons.book,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          book['title'],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Yazar: ${book['author']}',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            if (book['description'] != null &&
                book['description'].isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                book['description'],
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 4),
            Text(
              'Ekleme: ${_formatDate(book['addedDate'])}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (book['finishedDate'] != null) ...[
              Text(
                'Bitirme: ${_formatDate(book['finishedDate'])}',
                style: TextStyle(color: Colors.green[600], fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatsCard(List<Map<String, dynamic>> books) {
    int okuduCount = books.where((b) => b['status'] == 'okudu').length;
    int okuyorCount = books.where((b) => b['status'] == 'okuyor').length;
    int okuyacakCount = books.where((b) => b['status'] == 'okuyacak').length;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal[100]!, Colors.teal[50]!]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$okuduCount',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              Text(
                'Okudu',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '$okuyorCount',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Text(
                'Okuyor',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '$okuyacakCount',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              Text(
                'Okuyacak',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kitap Listesi'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(widget.parentUsername)
            .collection('books')
            .orderBy('addedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var books = snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.book, size: 64, color: Colors.teal[300]),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Henüz kitap eklenmemiş',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Öğretmeninizin size kitap eklemesini bekleyin',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildStatsCard(books),
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.teal[700],
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.teal[700],
                        tabs: [
                          Tab(text: 'Tümü'),
                          Tab(text: 'Okuyor'),
                          Tab(text: 'Okudu'),
                          Tab(text: 'Okuyacak'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tüm kitaplar
                            ListView.builder(
                              itemCount: books.length,
                              itemBuilder: (context, index) {
                                return _buildBookCard(books[index]);
                              },
                            ),
                            // Okuyor
                            ListView.builder(
                              itemCount: books
                                  .where((b) => b['status'] == 'okuyor')
                                  .length,
                              itemBuilder: (context, index) {
                                var filteredBooks = books
                                    .where((b) => b['status'] == 'okuyor')
                                    .toList();
                                return _buildBookCard(filteredBooks[index]);
                              },
                            ),
                            // Okudu
                            ListView.builder(
                              itemCount: books
                                  .where((b) => b['status'] == 'okudu')
                                  .length,
                              itemBuilder: (context, index) {
                                var filteredBooks = books
                                    .where((b) => b['status'] == 'okudu')
                                    .toList();
                                return _buildBookCard(filteredBooks[index]);
                              },
                            ),
                            // Okuyacak
                            ListView.builder(
                              itemCount: books
                                  .where((b) => b['status'] == 'okuyacak')
                                  .length,
                              itemBuilder: (context, index) {
                                var filteredBooks = books
                                    .where((b) => b['status'] == 'okuyacak')
                                    .toList();
                                return _buildBookCard(filteredBooks[index]);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
