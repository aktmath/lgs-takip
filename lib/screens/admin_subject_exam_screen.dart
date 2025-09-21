import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSubjectExamScreen extends StatefulWidget {
  @override
  _AdminSubjectExamScreenState createState() => _AdminSubjectExamScreenState();
}

class _AdminSubjectExamScreenState extends State<AdminSubjectExamScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();

  List<Map<String, dynamic>> students = [];
  bool _isLoading = false;
  String _selectedSubject = 'matematik';
  int _selectedTabIndex = 0; // 0: Yeni Deneme, 1: Geçmiş Denemeler

  // Her öğrenci için controller'lar
  Map<String, Map<String, TextEditingController>> studentControllers = {};

  final Map<String, String> _subjects = {
    'matematik': 'Matematik',
    'fen': 'Fen Bilimleri',
    'turkce': 'Türkçe',
    'din': 'Din Bilgisi',
    'ingilizce': 'İngilizce',
    'inkilap': 'İnkılap Tarihi',
  };

  final Map<String, int> _subjectQuestionCounts = {
    'matematik': 20,
    'fen': 20,
    'turkce': 20,
    'din': 10,
    'ingilizce': 10,
    'inkilap': 10,
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

      // Okul numarasına göre sırala
      tempStudents.sort((a, b) {
        int noA = int.tryParse(a['schoolNo'].toString()) ?? 0;
        int noB = int.tryParse(b['schoolNo'].toString()) ?? 0;
        return noA.compareTo(noB);
      });

      setState(() {
        students = tempStudents;
      });

      _initControllers();
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  void _initControllers() {
    studentControllers.clear();
    for (var student in students) {
      String studentKey = '${student['parentId']}_${student['name']}';
      studentControllers[studentKey] = {
        'dogru': TextEditingController(),
        'yanlis': TextEditingController(),
        'bos': TextEditingController(),
      };
    }
  }

  double _calculateNet(int dogru, int yanlis) {
    double net = dogru - (yanlis / 3.0);
    return net < 0 ? 0.0 : net;
  }

  Color _getNetColor(double net, int maxQuestions) {
    double percentage = (net / maxQuestions) * 100;
    if (percentage >= 70) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  void _saveSubjectExam() async {
    if (_examNameController.text.trim().isEmpty ||
        _examDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deneme adı ve tarihi boş bırakılamaz')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> attendedStudents = [];
      List<String> absentStudents = [];

      for (var student in students) {
        String studentKey = '${student['parentId']}_${student['name']}';
        var controllers = studentControllers[studentKey]!;

        int dogru = int.tryParse(controllers['dogru']!.text) ?? 0;
        int yanlis = int.tryParse(controllers['yanlis']!.text) ?? 0;
        int bos = int.tryParse(controllers['bos']!.text) ?? 0;

        if (dogru > 0 || yanlis > 0 || bos > 0) {
          // Katılan öğrenci
          attendedStudents.add(student['name']);
          double net = _calculateNet(dogru, yanlis);

          await _db
              .collection('users')
              .doc(student['parentId'])
              .collection('subject_exams')
              .add({
                'examName': _examNameController.text.trim(),
                'examDate': _examDateController.text.trim(),
                'subject': _selectedSubject,
                'subjectName': _subjects[_selectedSubject],
                'dogru': dogru,
                'yanlis': yanlis,
                'bos': bos,
                'net': net,
                'maxQuestions': _subjectQuestionCounts[_selectedSubject],
                'timestamp': FieldValue.serverTimestamp(),
                'addedBy': 'admin',
              });

          // Veliye başarı bildirimi gönder
          await _db
              .collection('users')
              .doc(student['parentId'])
              .collection('notifications')
              .add({
                'type': 'subject_exam',
                'message':
                    '${student['name']} - ${_subjects[_selectedSubject]} dersinden ${_examNameController.text.trim()} denemesi tamamlandı. Net: ${net.toStringAsFixed(2)}',
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
                'sentBy': 'admin',
                'examData': {
                  'subject': _selectedSubject,
                  'subjectName': _subjects[_selectedSubject],
                  'net': net,
                  'dogru': dogru,
                  'yanlis': yanlis,
                  'bos': bos,
                },
              });
        } else {
          // Katılmayan öğrenci
          absentStudents.add(student['name']);

          // Veliye yokluk bildirimi gönder
          await _db
              .collection('users')
              .doc(student['parentId'])
              .collection('notifications')
              .add({
                'type': 'subject_exam_absent',
                'message':
                    '${student['name']} öğrenciniz ${_examDateController.text.trim()} tarihli ${_subjects[_selectedSubject]} ders denemesine girmemiştir.',
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
                'sentBy': 'admin',
              });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ders denemesi kaydedildi!\nKatılan: ${attendedStudents.length}, Katılmayan: ${absentStudents.length}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Formu temizle
      _examNameController.clear();
      _examDateController.clear();
      _initControllers();
    } catch (e) {
      print('Error saving subject exam: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata oluştu: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteSubjectExam(
    String parentId,
    String examId,
    String examName,
    String studentName,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ders Denemesi Sil'),
        content: Text(
          '$studentName öğrencisinin \"$examName\" ders denemesini silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
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
            .collection('subject_exams')
            .doc(examId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ders denemesi başarıyla silindi')),
        );

        setState(() {}); // Listeyi yenile
      } catch (e) {
        print('Error deleting subject exam: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız')));
      }
    }
  }

  Future<void> _editSubjectExam(
    String parentId,
    String examId,
    Map<String, dynamic> currentExam,
  ) async {
    final dogruController = TextEditingController(
      text: currentExam['dogru'].toString(),
    );
    final yanlisController = TextEditingController(
      text: currentExam['yanlis'].toString(),
    );
    final bosController = TextEditingController(
      text: currentExam['bos'].toString(),
    );

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ders Denemesi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${currentExam['examName']} - ${currentExam['subjectName']}'),
            SizedBox(height: 16),
            TextField(
              controller: dogruController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Doğru',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: yanlisController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Yanlış',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: bosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Boş',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
        int dogru = int.tryParse(dogruController.text) ?? 0;
        int yanlis = int.tryParse(yanlisController.text) ?? 0;
        int bos = int.tryParse(bosController.text) ?? 0;
        double net = _calculateNet(dogru, yanlis);

        await _db
            .collection('users')
            .doc(parentId)
            .collection('subject_exams')
            .doc(examId)
            .update({'dogru': dogru, 'yanlis': yanlis, 'bos': bos, 'net': net});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ders denemesi başarıyla güncellendi')),
        );

        setState(() {}); // Listeyi yenile
      } catch (e) {
        print('Error updating subject exam: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Güncelleme başarısız')));
      }
    }

    dogruController.dispose();
    yanlisController.dispose();
    bosController.dispose();
  }

  Future<List<Map<String, dynamic>>> _getAllSubjectExams() async {
    List<Map<String, dynamic>> allExams = [];

    try {
      for (var student in students) {
        var examsSnapshot = await _db
            .collection('users')
            .doc(student['parentId'])
            .collection('subject_exams')
            .orderBy('timestamp', descending: true)
            .get();

        for (var examDoc in examsSnapshot.docs) {
          var examData = examDoc.data();
          allExams.add({
            'examId': examDoc.id,
            'parentId': student['parentId'],
            'studentName': student['name'],
            'studentNo': student['schoolNo'],
            'examName': examData['examName'] ?? 'Bilinmiyor',
            'examDate': examData['examDate'] ?? 'Tarih yok',
            'subject': examData['subject'] ?? '',
            'subjectName': examData['subjectName'] ?? '',
            'dogru': examData['dogru'] ?? 0,
            'yanlis': examData['yanlis'] ?? 0,
            'bos': examData['bos'] ?? 0,
            'net': examData['net'] ?? 0.0,
            'maxQuestions': examData['maxQuestions'] ?? 20,
            'timestamp': examData['timestamp'],
            'fullData': examData,
          });
        }
      }

      allExams.sort((a, b) {
        var aTime = a['timestamp'] as Timestamp?;
        var bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      print('Error loading all subject exams: $e');
    }

    return allExams;
  }

  Widget _buildPreviousExamsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllSubjectExams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Henüz ders denemesi yok',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        var allExams = snapshot.data!;

        // Deneme adı ve derse göre grupla
        Map<String, Map<String, List<Map<String, dynamic>>>>
        examsByNameAndSubject = {};
        for (var exam in allExams) {
          String examKey = '${exam['examName']} - ${exam['examDate']}';
          String subject = exam['subject'];

          if (!examsByNameAndSubject.containsKey(examKey)) {
            examsByNameAndSubject[examKey] = {};
          }
          if (!examsByNameAndSubject[examKey]!.containsKey(subject)) {
            examsByNameAndSubject[examKey]![subject] = [];
          }
          examsByNameAndSubject[examKey]![subject]!.add(exam);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: examsByNameAndSubject.length,
          itemBuilder: (context, index) {
            String examKey = examsByNameAndSubject.keys.elementAt(index);
            var subjectGroups = examsByNameAndSubject[examKey]!;

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  examKey,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${subjectGroups.length} ders'),
                children: subjectGroups.entries.map((subjectEntry) {
                  String subject = subjectEntry.key;
                  List<Map<String, dynamic>> examResults = subjectEntry.value;
                  String subjectName = _subjects[subject] ?? subject;

                  return ExpansionTile(
                    title: Text(
                      subjectName,
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    subtitle: Text('${examResults.length} öğrenci'),
                    children: examResults.map((exam) {
                      Color netColor = _getNetColor(
                        exam['net'],
                        exam['maxQuestions'],
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: netColor.withOpacity(0.2),
                          child: Text(
                            exam['studentNo'].toString(),
                            style: TextStyle(
                              color: netColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(exam['studentName']),
                        subtitle: Text(
                          'D:${exam['dogru']} Y:${exam['yanlis']} B:${exam['bos']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: netColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Net: ${exam['net'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: netColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editSubjectExam(
                                    exam['parentId'],
                                    exam['examId'],
                                    exam['fullData'],
                                  );
                                } else if (value == 'delete') {
                                  _deleteSubjectExam(
                                    exam['parentId'],
                                    exam['examId'],
                                    exam['examName'],
                                    exam['studentName'],
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
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student, int index) {
    String studentKey = '${student['parentId']}_${student['name']}';
    var controllers = studentControllers[studentKey]!;

    // Net hesaplama (real-time)
    int dogru = int.tryParse(controllers['dogru']!.text) ?? 0;
    int yanlis = int.tryParse(controllers['yanlis']!.text) ?? 0;
    double net = _calculateNet(dogru, yanlis);
    Color netColor = _getNetColor(
      net,
      _subjectQuestionCounts[_selectedSubject]!,
    );

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Sıra no ve isim
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student['schoolNo']} - ${student['name']}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (net > 0)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: netColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Net: ${net.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: netColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Doğru
            Expanded(
              child: TextField(
                controller: controllers['dogru']!,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Doğru',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            SizedBox(width: 8),
            // Yanlış
            Expanded(
              child: TextField(
                controller: controllers['yanlis']!,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Yanlış',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            SizedBox(width: 8),
            // Boş
            Expanded(
              child: TextField(
                controller: controllers['bos']!,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Boş',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
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
          title: Text('Ders Denemeleri Yönetimi'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Yeni Ders Denemesi', icon: Icon(Icons.add_circle)),
              Tab(text: 'Geçmiş Denemeler', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Yeni ders denemesi sekmesi
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Form kartı
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ders Denemesi Bilgileri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSubject,
                            decoration: InputDecoration(
                              labelText: 'Ders Seçin',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.subject),
                            ),
                            items: _subjects.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  '${entry.value} (${_subjectQuestionCounts[entry.key]} soru)',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSubject = value!;
                              });
                            },
                          ),
                          SizedBox(height: 12),
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

                  // Öğrenci listesi
                  Card(
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Öğrenci Listesi (${students.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Doğru',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Yanlış',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Boş', textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        ),
                        if (students.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Henüz öğrenci kaydedilmemiş'),
                          )
                        else
                          Column(
                            children: students.asMap().entries.map((entry) {
                              return _buildStudentRow(entry.value, entry.key);
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Kaydet butonu
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _saveSubjectExam,
                            icon: Icon(Icons.save),
                            label: Text('Ders Denemesini Kaydet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo[600],
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

    studentControllers.forEach((studentKey, controllers) {
      controllers.forEach((type, controller) {
        controller.dispose();
      });
    });

    super.dispose();
  }
}
