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
    return Scaffold(
      appBar: AppBar(
        title: Text('Deneme Sonuçları Girişi'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
