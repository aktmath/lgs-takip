import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminExamScreen extends StatefulWidget {
  @override
  _AdminExamScreenState createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();

  List<Map<String, dynamic>> students = [];
  bool _isLoading = false;
  int _selectedTabIndex = 0; // 0: Yeni Deneme, 1: Geçmiş Denemeler

  // Her öğrenci için ders bilgileri
  Map<String, Map<String, Map<String, TextEditingController>>>
  studentControllers = {};

  final List<String> _dersler = [
    'turkce',
    'matematik',
    'fen',
    'inkilap',
    'din',
    'ingilizce',
  ];
  final Map<String, String> _dersIsimleri = {
    'turkce': 'Türkçe',
    'matematik': 'Matematik',
    'fen': 'Fen Bilimleri',
    'inkilap': 'İnkılap Tarihi',
    'din': 'Din Kültürü',
    'ingilizce': 'İngilizce',
  };

  final Map<String, double> _dersKatsayilari = {
    'turkce': 4.2538,
    'matematik': 4.348,
    'fen': 4.1230,
    'inkilap': 1.666,
    'din': 1.899,
    'ingilizce': 1.5075,
  };

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    try {
      var snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();

      List<Map<String, dynamic>> tempStudents = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        var student = data['student'] as Map<String, dynamic>;
        tempStudents.add({
          'parentId': doc.id,
          'name': student['name'] ?? '',
          'schoolNo': student['schoolNo'] ?? '',
        });
      }

      setState(() {
        students = tempStudents;
      });

      // Her öğrenci için controller'ları oluştur
      _initControllers();
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  void _initControllers() {
    studentControllers.clear();
    for (var student in students) {
      String studentKey = '${student['parentId']}_${student['name']}';
      studentControllers[studentKey] = {};

      for (String ders in _dersler) {
        studentControllers[studentKey]![ders] = {
          'dogru': TextEditingController(),
          'yanlis': TextEditingController(),
          'bos': TextEditingController(),
        };
      }
    }
  }

  int _calculateNet(int dogru, int yanlis) {
    int net = dogru - (yanlis ~/ 3);
    return net < 0 ? 0 : net;
  }

  double _calculateLGSScore(Map<String, int> nets) {
    double puan = 0.0;
    _dersKatsayilari.forEach((ders, katsayi) {
      puan += (nets[ders] ?? 0) * katsayi;
    });
    return puan + 194.752082;
  }

  void _saveAllExams() async {
    if (_examNameController.text.isEmpty || _examDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deneme adı ve tarihi boş bırakılamaz')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Her öğrenci için deneme sonucunu kaydet
      for (var student in students) {
        String studentKey = '${student['parentId']}_${student['name']}';
        Map<String, Map<String, int>> dersData = {};
        Map<String, int> nets = {};

        // Her ders için verileri topla
        bool hasData = false;
        for (String ders in _dersler) {
          var controllers = studentControllers[studentKey]![ders]!;
          int dogru = int.tryParse(controllers['dogru']!.text) ?? 0;
          int yanlis = int.tryParse(controllers['yanlis']!.text) ?? 0;
          int bos = int.tryParse(controllers['bos']!.text) ?? 0;

          if (dogru > 0 || yanlis > 0 || bos > 0) {
            hasData = true;
          }

          dersData[ders] = {'dogru': dogru, 'yanlis': yanlis, 'bos': bos};

          nets[ders] = _calculateNet(dogru, yanlis);
        }

        // Eğer bu öğrenci için veri girildiyse kaydet
        if (hasData) {
          double lgsScore = _calculateLGSScore(nets);

          await _db
              .collection('users')
              .doc(student['parentId'])
              .collection('exams')
              .add({
                'name': _examNameController.text,
                'date': _examDateController.text,
                'timestamp': FieldValue.serverTimestamp(),
                'studentName': student['name'],
                'lgsScore': lgsScore,
                'totalNet': nets.values.reduce((a, b) => a + b),
                ...dersData,
              });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm deneme sonuçları başarıyla kaydedildi')),
      );

      // Formu temizle
      _examNameController.clear();
      _examDateController.clear();
      _initControllers();
    } catch (e) {
      print('Error saving exams: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata oluştu: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // YENİ: Deneme silme fonksiyonu
  Future<void> _deleteExam(
    String parentId,
    String examId,
    String examName,
    String studentName,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deneme Sil'),
        content: Text(
          '$studentName öğrencisinin \"$examName\" denemesini silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
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
            .collection('exams')
            .doc(examId)
            .delete();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deneme başarıyla silindi')));
      } catch (e) {
        print('Error deleting exam: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız')));
      }
    }
  }

  // YENİ: Geçmiş denemeleri listeleyen widget
  Widget _buildPreviousExamsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllExams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Henüz deneme sonucu yok',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        var allExams = snapshot.data!;

        // Deneme adına göre grupla
        Map<String, List<Map<String, dynamic>>> examsByName = {};
        for (var exam in allExams) {
          String examName = exam['examName'];
          if (!examsByName.containsKey(examName)) {
            examsByName[examName] = [];
          }
          examsByName[examName]!.add(exam);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: examsByName.length,
          itemBuilder: (context, index) {
            String examName = examsByName.keys.elementAt(index);
            List<Map<String, dynamic>> examResults = examsByName[examName]!;

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  examName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${examResults.length} öğrenci - ${examResults.first['date']}',
                ),
                children: examResults.map((exam) {
                  return ListTile(
                    title: Text(exam['studentName']),
                    subtitle: Text(
                      'LGS: ${exam['lgsScore'].toStringAsFixed(2)} - Net: ${exam['totalNet'].toStringAsFixed(2)}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteExam(
                            exam['parentId'],
                            exam['examId'],
                            examName,
                            exam['studentName'],
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Sil'),
                            ],
                          ),
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

  // YENİ: Tüm denemeleri getiren fonksiyon
  Future<List<Map<String, dynamic>>> _getAllExams() async {
    List<Map<String, dynamic>> allExams = [];

    try {
      for (var student in students) {
        var examsSnapshot = await _db
            .collection('users')
            .doc(student['parentId'])
            .collection('exams')
            .orderBy('timestamp', descending: true)
            .get();

        for (var examDoc in examsSnapshot.docs) {
          var examData = examDoc.data();
          allExams.add({
            'examId': examDoc.id,
            'parentId': student['parentId'],
            'studentName': student['name'],
            'examName': examData['name'] ?? 'Bilinmiyor',
            'date': examData['date'] ?? 'Tarih yok',
            'lgsScore': examData['lgsScore'] ?? 0.0,
            'totalNet': examData['totalNet'] ?? 0,
            'timestamp': examData['timestamp'],
          });
        }
      }

      // Zamana göre sırala
      allExams.sort((a, b) {
        var aTime = a['timestamp'] as Timestamp?;
        var bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      print('Error loading all exams: $e');
    }

    return allExams;
  }

  Widget _buildStudentRow(Map<String, dynamic> student) {
    String studentKey = '${student['parentId']}_${student['name']}';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student['name']} (No: ${student['schoolNo']})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            ...(_dersler.map((ders) {
              var controllers = studentControllers[studentKey]![ders]!;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dersIsimleri[ders]!,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllers['dogru']!,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Doğru',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controllers['yanlis']!,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Yanlış',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controllers['bos']!,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Boş',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Deneme Sonuçları Yönetimi'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Yeni Deneme', icon: Icon(Icons.add)),
              Tab(text: 'Geçmiş Denemeler', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Yeni deneme ekleme sekmesi
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _examNameController,
                            decoration: InputDecoration(
                              labelText: 'Deneme Adı',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.quiz),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _examDateController,
                            decoration: InputDecoration(
                              labelText: 'Tarih (gg.aa.yyyy)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: students.isEmpty
                        ? Center(child: Text('Henüz öğrenci kaydedilmemiş'))
                        : ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              return _buildStudentRow(students[index]);
                            },
                          ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _saveAllExams,
                            icon: Icon(Icons.save),
                            label: Text('Tüm Sonuçları Kaydet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Geçmiş denemeler sekmesi
            _buildPreviousExamsList(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _examDateController.dispose();

    // Tüm controller'ları temizle
    studentControllers.forEach((studentKey, dersMap) {
      dersMap.forEach((ders, controllerMap) {
        controllerMap.forEach((type, controller) {
          controller.dispose();
        });
      });
    });

    super.dispose();
  }
}
