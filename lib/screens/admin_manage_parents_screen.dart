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
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lütfen tüm alanları doldurun')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.collection('users').doc(_parentNameController.text).set({
        'password': _passwordController.text,
        'role': 'parent',
        'student': {
          'name': _studentNameController.text,
          'schoolNo': _studentNumberController.text,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veli ve öğrenci başarıyla eklendi')),
      );

      _parentNameController.clear();
      _studentNameController.clear();
      _studentNumberController.clear();
      _passwordController.clear();
    } catch (e) {
      print('Error adding parent: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteParent(String parentId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Veli Sil'),
        content: Text('Bu veliyi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.collection('users').doc(parentId).delete();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Veli silindi')));
      } catch (e) {
        print('Error deleting parent: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Silme başarısız: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Veli Yönetimi'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Veli Ekle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _parentNameController,
                      decoration: InputDecoration(
                        labelText: 'Veli Kullanıcı Adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _studentNameController,
                      decoration: InputDecoration(
                        labelText: 'Öğrenci Adı Soyadı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _studentNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Okul Numarası',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _addParent,
                              icon: Icon(Icons.add),
                              label: Text('Veli Ekle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Kayıtlı Veliler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('users')
                            .where('role', isEqualTo: 'parent')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          var parents = snapshot.data!.docs;

                          if (parents.isEmpty) {
                            return Center(
                              child: Text('Henüz veli kaydedilmemiş'),
                            );
                          }

                          return ListView.builder(
                            itemCount: parents.length,
                            itemBuilder: (context, index) {
                              var parent = parents[index];
                              var parentData =
                                  parent.data() as Map<String, dynamic>;
                              var student = parentData['student'] ?? {};

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                title: Text(parent.id),
                                subtitle: Text(
                                  'Öğrenci: ${student['name'] ?? 'Bilinmiyor'}\nOkul No: ${student['schoolNo'] ?? 'Bilinmiyor'}',
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
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
            ),
          ],
        ),
      ),
    );
  }
}
