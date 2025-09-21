import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentSubjectExamScreen extends StatefulWidget {
  final String parentUsername;

  const ParentSubjectExamScreen({super.key, required this.parentUsername});

  @override
  State<ParentSubjectExamScreen> createState() =>
      _ParentSubjectExamScreenState();
}

class _ParentSubjectExamScreenState extends State<ParentSubjectExamScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? studentInfo;
  bool _isLoading = false;

  final Map<String, String> _subjects = {
    'matematik': 'Matematik',
    'fen': 'Fen Bilimleri',
    'turkce': 'Türkçe',
    'din': 'Din Bilgisi',
    'ingilizce': 'İngilizce',
    'inkilap': 'İnkılap Tarihi',
  };

  final Map<String, Color> _subjectColors = {
    'matematik': Colors.blue,
    'fen': Colors.green,
    'turkce': Colors.red,
    'din': Colors.purple,
    'ingilizce': Colors.orange,
    'inkilap': Colors.teal,
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
    _loadStudentInfo();
  }

  void _loadStudentInfo() async {
    try {
      var doc = await _db.collection('users').doc(widget.parentUsername).get();
      if (doc.exists && doc.data()!.containsKey('student')) {
        setState(() {
          studentInfo = doc['student'];
        });
      }
    } catch (e) {
      print('Error fetching student info: $e');
    }
  }

  Color _getNetColor(double net, int maxQuestions) {
    double percentage = (net / maxQuestions) * 100;
    if (percentage >= 70) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  Future<List<Map<String, dynamic>>> _getSubjectExams() async {
    List<Map<String, dynamic>> allExams = [];

    try {
      var examsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('subject_exams')
          .orderBy('timestamp', descending: true)
          .get();

      for (var examDoc in examsSnapshot.docs) {
        var examData = examDoc.data();
        allExams.add({
          'examId': examDoc.id,
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
        });
      }
    } catch (e) {
      print('Error loading subject exams: $e');
    }

    return allExams;
  }

  Widget _buildSubjectCard(String subject, List<Map<String, dynamic>> exams) {
    String subjectName = _subjects[subject] ?? subject;
    Color subjectColor = _subjectColors[subject] ?? Colors.grey;
    int maxQuestions = _subjectQuestionCounts[subject] ?? 20;

    // En son 5 denemeyi al
    var recentExams = exams.take(5).toList();

    // Ortalama hesapla
    double totalNet = 0;
    for (var exam in exams) {
      totalNet += exam['net'];
    }
    double averageNet = exams.isNotEmpty ? totalNet / exams.length : 0.0;

    // En yüksek net
    double maxNet = 0;
    for (var exam in exams) {
      if (exam['net'] > maxNet) maxNet = exam['net'];
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              subjectColor.withOpacity(0.1),
              subjectColor.withOpacity(0.05),
            ],
          ),
        ),
        child: ExpansionTile(
          leading: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: subjectColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getSubjectIcon(subject),
              color: subjectColor,
              size: 24,
            ),
          ),
          title: Text(
            subjectName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: subjectColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${exams.length} deneme • Ortalama: ${averageNet.toStringAsFixed(1)}',
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getNetColor(
                        maxNet,
                        maxQuestions,
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'En İyi: ${maxNet.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: _getNetColor(maxNet, maxQuestions),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: recentExams.map((exam) {
            Color netColor = _getNetColor(exam['net'], exam['maxQuestions']);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: subjectColor.withOpacity(0.3)),
              ),
              child: ListTile(
                title: Text(
                  exam['examName'],
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarih: ${exam['examDate']}'),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _buildScoreChip('D', exam['dogru'], Colors.green),
                        SizedBox(width: 8),
                        _buildScoreChip('Y', exam['yanlis'], Colors.red),
                        SizedBox(width: 8),
                        _buildScoreChip('B', exam['bos'], Colors.grey),
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: netColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Net: ${exam['net'].toStringAsFixed(1)}',
                    style: TextStyle(
                      color: netColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScoreChip(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label:$value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject) {
      case 'matematik':
        return Icons.calculate;
      case 'fen':
        return Icons.science;
      case 'turkce':
        return Icons.language;
      case 'din':
        return Icons.mosque;
      case 'ingilizce':
        return Icons.translate;
      case 'inkilap':
        return Icons.history_edu;
      default:
        return Icons.subject;
    }
  }

  Widget _buildPerformanceChart(List<Map<String, dynamic>> allExams) {
    if (allExams.isEmpty) return SizedBox();

    // Derse göre grupla
    Map<String, List<Map<String, dynamic>>> examsBySubject = {};
    for (var exam in allExams) {
      String subject = exam['subject'];
      if (!examsBySubject.containsKey(subject)) {
        examsBySubject[subject] = [];
      }
      examsBySubject[subject]!.add(exam);
    }

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Ders Performansı Özeti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: examsBySubject.entries.map((entry) {
                  String subject = entry.key;
                  List<Map<String, dynamic>> exams = entry.value;
                  Color subjectColor = _subjectColors[subject] ?? Colors.grey;

                  double totalNet = 0;
                  for (var exam in exams) {
                    totalNet += exam['net'];
                  }
                  double averageNet = exams.isNotEmpty
                      ? totalNet / exams.length
                      : 0.0;
                  int maxQuestions = _subjectQuestionCounts[subject] ?? 20;
                  double heightRatio = (averageNet / maxQuestions).clamp(
                    0.1,
                    1.0,
                  );

                  return Container(
                    margin: EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: (100 * heightRatio).clamp(20.0, 100.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                subjectColor,
                                subjectColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          averageNet.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: subjectColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getSubjectShort(subject),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${exams.length} deneme',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSubjectShort(String subject) {
    switch (subject) {
      case 'matematik':
        return 'MAT';
      case 'fen':
        return 'FEN';
      case 'turkce':
        return 'TÜR';
      case 'din':
        return 'DİN';
      case 'ingilizce':
        return 'İNG';
      case 'inkilap':
        return 'İNK';
      default:
        return subject.substring(0, 3).toUpperCase();
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ders Denemeleri'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getSubjectExams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ders denemeleri yükleniyor...'),
                ],
              ),
            );
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
                  SizedBox(height: 8),
                  Text(
                    'Öğretmeniniz ders denemeleri eklediğinde\nburadan görüntüleyebilirsiniz',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          var allExams = snapshot.data!;

          // Derse göre grupla
          Map<String, List<Map<String, dynamic>>> examsBySubject = {};
          for (var exam in allExams) {
            String subject = exam['subject'];
            if (!examsBySubject.containsKey(subject)) {
              examsBySubject[subject] = [];
            }
            examsBySubject[subject]!.add(exam);
          }

          return Column(
            children: [
              // Öğrenci bilgisi
              if (studentInfo != null) ...[
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Text(
                          studentInfo!['name'].substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[600],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentInfo!['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Okul No: ${studentInfo!['schoolNo']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // İstatistikler
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Toplam\nDeneme',
                      '${allExams.length}',
                      Colors.blue,
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      'Farklı\nDers',
                      '${examsBySubject.length}',
                      Colors.green,
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      'Bu Ay',
                      '${allExams.where((exam) {
                        if (exam['timestamp'] == null) return false;
                        DateTime examDate = (exam['timestamp'] as Timestamp).toDate();
                        DateTime now = DateTime.now();
                        return examDate.month == now.month && examDate.year == now.year;
                      }).length}',
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              // Performans grafiği
              _buildPerformanceChart(allExams),

              // Ders listesi
              Expanded(
                child: ListView(
                  children: examsBySubject.entries.map((entry) {
                    return _buildSubjectCard(entry.key, entry.value);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
