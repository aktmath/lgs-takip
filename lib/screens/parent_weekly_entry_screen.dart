import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentWeeklyEntryScreen extends StatefulWidget {
  final String parentUsername;

  const ParentWeeklyEntryScreen({Key? key, required this.parentUsername})
    : super(key: key);

  @override
  _ParentWeeklyEntryScreenState createState() =>
      _ParentWeeklyEntryScreenState();
}

class _ParentWeeklyEntryScreenState extends State<ParentWeeklyEntryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _hasAlreadyEntered = false;
  String _currentWeek = '';

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

  @override
  void initState() {
    super.initState();
    _currentWeek = DateTime.now().toIso8601String().substring(0, 10);
    _checkIfAlreadyEntered();
  }

  void _checkIfAlreadyEntered() async {
    try {
      var snapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('weekly_questions')
          .where('week', isEqualTo: _currentWeek)
          .get();

      setState(() {
        _hasAlreadyEntered = snapshot.docs.isNotEmpty;
      });

      if (_hasAlreadyEntered && snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        _controllers.forEach((ders, controller) {
          controller.text = (data[ders] ?? 0).toString();
        });
      }
    } catch (e) {
      print('Error checking previous entry: $e');
    }
  }

  void _saveWeeklyQuestions() async {
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
      if (_hasAlreadyEntered) {
        var snapshot = await _db
            .collection('users')
            .doc(widget.parentUsername)
            .collection('weekly_questions')
            .where('week', isEqualTo: _currentWeek)
            .get();

        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update({
            ...scores,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await _db
            .collection('users')
            .doc(widget.parentUsername)
            .collection('weekly_questions')
            .add({
              ...scores,
              'week': _currentWeek,
              'timestamp': FieldValue.serverTimestamp(),
              'enteredBy': 'parent',
            });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Haftalık soru sayıları başarıyla kaydedildi')),
      );

      setState(() {
        _hasAlreadyEntered = true;
      });
    } catch (e) {
      print('Error saving weekly questions: $e');
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
        title: Text('Haftalık Soru Girişi'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: _hasAlreadyEntered
                  ? Colors.blue.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _hasAlreadyEntered ? Icons.info : Icons.warning,
                      color: _hasAlreadyEntered ? Colors.blue : Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu Hafta ($_currentWeek)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _hasAlreadyEntered
                                  ? Colors.blue.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            _hasAlreadyEntered
                                ? 'Bu hafta için daha önce soru sayısı girmiştiniz. Tekrar düzenleme yapamazsınız, sadece görüntüleyebilirsiniz.'
                                : 'Bu hafta çözülen soru sayılarını girebilirsiniz. Kaydetmeden önce dikkatli kontrol edin.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _hasAlreadyEntered
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ders Bazında Çözülen Soru Sayıları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          children: _controllers.entries.map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: TextField(
                                controller: entry.value,
                                keyboardType: TextInputType.number,
                                enabled: !_hasAlreadyEntered,
                                decoration: InputDecoration(
                                  labelText:
                                      '${_dersIsimleri[entry.key]} - Çözülen Soru Sayısı',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.quiz),
                                  filled: _hasAlreadyEntered,
                                  fillColor: _hasAlreadyEntered
                                      ? Colors.grey.shade100
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (!_hasAlreadyEntered) ...[
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _saveWeeklyQuestions,
                                  icon: Icon(Icons.save),
                                  label: Text('Kaydet'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geçmiş Kayıtlarınız',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 100,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('users')
                            .doc(widget.parentUsername)
                            .collection('weekly_questions')
                            .orderBy('week', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          var entries = snapshot.data!.docs;
                          if (entries.isEmpty) {
                            return Center(child: Text('Henüz kayıt yok'));
                          }

                          return ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              var entry = entries[index];
                              var data = entry.data() as Map<String, dynamic>;

                              int totalQuestions = 0;
                              _controllers.keys.forEach((ders) {
                                totalQuestions += (data[ders] as int? ?? 0);
                              });

                              return ListTile(
                                dense: true,
                                title: Text('Hafta: ${data['week']}'),
                                subtitle: Text('Toplam ${totalQuestions} soru'),
                                trailing: Text(
                                  data['enteredBy'] == 'parent'
                                      ? 'Veli'
                                      : 'Öğretmen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
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

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
}
