import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageParentsScreen extends StatefulWidget {
  const AdminManageParentsScreen({Key? key}) : super(key: key);

  @override
  _AdminManageParentsScreenState createState() =>
      _AdminManageParentsScreenState();
}

class _AdminManageParentsScreenState extends State<AdminManageParentsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentNumberController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _addParent() async {
    if (_parentNameController.text.isEmpty ||
        _studentNameController.text.isEmpty ||
        _studentNumberController.text.isEmpty ||
        _passwordController.text.isEmpty)
      return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Burada 'student' field'ı map olarak ekleniyor ve eksik alan yok
      await _db.collection('users').doc(_parentNameController.text).set({
        'password': _passwordController.text,
        'student': {
          'name': _studentNameController.text,
          'surname': '', // Soyadı opsiyonel, boş bırakıyoruz
          'schoolNo': _studentNumberController.text,
          'exams': [], // Denemeler için boş liste
          'books': [], // Kitaplar için boş liste
          'weeklyQuestions': [], // Haftalık sorular için boş liste
        },
        'announcements': [],
        'notifications': [],
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Veli ve öğrenci eklendi')));

      _parentNameController.clear();
      _studentNameController.clear();
      _studentNumberController.clear();
      _passwordController.clear();
    } catch (e) {
      print('Error adding parent: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu, tekrar deneyin')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteParent(String parentId) async {
    try {
      await _db.collection('users').doc(parentId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Veli silindi')));
    } catch (e) {
      print('Error deleting parent: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme başarısız')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Velileri Yönet')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _parentNameController,
              decoration: InputDecoration(labelText: 'Veli Kullanıcı Adı'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Şifre'),
            ),
            TextField(
              controller: _studentNameController,
              decoration: InputDecoration(labelText: 'Öğrenci Adı Soyadı'),
            ),
            TextField(
              controller: _studentNumberController,
              decoration: InputDecoration(labelText: 'Okul Numarası'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: _addParent, child: Text('Ekle')),
            SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  var parents = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: parents.length,
                    itemBuilder: (context, index) {
                      var parent = parents[index];
                      var studentMap = parent.data() as Map<String, dynamic>;
                      var student = studentMap['student'] ?? {};
                      return ListTile(
                        title: Text(parent.id),
                        subtitle: Text(
                          'Öğrenci: ${student['name'] ?? ''} (${student['schoolNo'] ?? ''})',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteParent(parent.id),
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
