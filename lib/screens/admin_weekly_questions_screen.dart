import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWeeklyQuestionsScreen extends StatefulWidget {
  @override
  _AdminWeeklyQuestionsScreenState createState() =>
      _AdminWeeklyQuestionsScreenState();
}

class _AdminWeeklyQuestionsScreenState
    extends State<AdminWeeklyQuestionsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedParent;
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {
    'turkce': TextEditingController(),
    'matematik': TextEditingController(),
    'fen': TextEditingController(),
    'ingilizce': TextEditingController(),
    'din': TextEditingController(),
    'inkilap': TextEditingController(),
  };

  final Map<String, String> _dersIsimleri = {
    'turkce': 'Türkçe',
    'matematik': 'Matematik',
    'fen': 'Fen Bilimleri',
    'ingilizce': 'İngilizce',
    'din': 'Din Kültürü',
    'inkilap': 'İnkılap Tarihi',
  };

  Future<List<Map<String, dynamic>>> _getParentsWithStudents() async {
    var snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();
    return snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'studentName': data['student']['name'] ?? 'Bilinmiyor',
        'studentNo': data['student']['schoolNo'] ?? 'Bilinmiyor',
      };
    }).toList();
  }

  void _saveWeeklyScores() async {
    if (_selectedParent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lütfen bir öğrenci seçin')));
      return;
    }

    bool hasEmpty = _controllers.values.any(
      (controller) => controller.text.isEmpty,
    );
    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm ders soru sayılarını girin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, int> scores = {};
    _controllers.forEach((subject, controller) {
      scores[subject] = int.tryParse(controller.text) ?? 0;
    });

    try {
      await _db
          .collection('users')
          .doc(_selectedParent)
          .collection('weekly_questions')
          .add({
            ...scores,
            'week': DateTime.now().toIso8601String().substring(0, 10),
            'timestamp': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Haftalık sorular başarıyla kaydedildi')),
      );

      _controllers.forEach((key, controller) => controller.clear());
      setState(() {
        _selectedParent = null;
      });
    } catch (e) {
      print('Error saving weekly scores: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt sırasında hata oluştu')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Haftalık Soru Sayıları'),
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
                      'Öğrenci Seç',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getParentsWithStudents(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        var parents = snapshot.data!;
                        if (parents.isEmpty) {
                          return Text('Henüz öğrenci kaydedilmemiş');
                        }

                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Öğrenci Seçin',
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
                          onChanged: (val) {
                            setState(() {
                              _selectedParent = val;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_selectedParent != null) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haftalık Çözülen Soru Sayıları',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      ...(_controllers.entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: entry.value,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  '${_dersIsimleri[entry.key]} - Çözülen Soru Sayısı',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.quiz),
                            ),
                          ),
                        );
                      }).toList()),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _saveWeeklyScores,
                                icon: Icon(Icons.save),
                                label: Text('Kaydet'),
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
            ],
          ],
        ),
      ),
    );
  }
}
