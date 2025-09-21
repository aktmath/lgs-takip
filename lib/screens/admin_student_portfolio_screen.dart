import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStudentPortfolioScreen extends StatefulWidget {
  @override
  _AdminStudentPortfolioScreenState createState() =>
      _AdminStudentPortfolioScreenState();
}

class _AdminStudentPortfolioScreenState
    extends State<AdminStudentPortfolioScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> students = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

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
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openStudentDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(student: student),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[600],
          child: Text(
            student['name'].substring(0, 1).toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student['name'],
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          'Okul No: ${student['schoolNo']}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16,
        ),
        onTap: () => _openStudentDetail(student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Öğrenci Portfolyoları'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Henüz öğrenci kaydedilmemiş',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header istatistik
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[100]!, Colors.blue[50]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue[700], size: 28),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam Öğrenci',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${students.length}',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Text(
                        'Detayları görüntülemek için\nöğrenci kartına dokunun',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                // Öğrenci listesi
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentCard(students[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// Ayrı detay ekranı
class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({Key? key, required this.student})
    : super(key: key);

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? studentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudentPortfolio();
  }

  void _loadStudentPortfolio() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String parentId = widget.student['parentId'];

      // Öğrenci temel bilgileri
      var userDoc = await _db.collection('users').doc(parentId).get();
      var userData = userDoc.data() ?? {};

      // Genel deneme sonuçları
      var examsSnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('exams')
          .orderBy('timestamp', descending: true)
          .get();

      // Ders denemeleri sonuçları - YENİ EKLENEN
      var subjectExamsSnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('subject_exams')
          .orderBy('timestamp', descending: true)
          .get();

      // Kitaplar
      var booksSnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('books')
          .orderBy('addedDate', descending: true)
          .get();

      // Haftalık sorular
      var weeklySnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('weekly_questions')
          .orderBy('week', descending: true)
          .get();

      // Devamsızlık kayıtları
      var attendanceSnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('attendance')
          .orderBy('date', descending: true)
          .get();

      setState(() {
        studentData = {
          'info': userData['student'] ?? {},
          'exams': examsSnapshot.docs.map((doc) => doc.data()).toList(),
          'subjectExams': subjectExamsSnapshot.docs
              .map((doc) => doc.data())
              .toList(), // YENİ EKLENEN
          'books': booksSnapshot.docs.map((doc) => doc.data()).toList(),
          'weekly': weeklySnapshot.docs.map((doc) => doc.data()).toList(),
          'attendance': attendanceSnapshot.docs
              .map((doc) => doc.data())
              .toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading portfolio: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildExamChart() {
    if (studentData == null || studentData!['exams'].isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                'Henüz genel deneme sonucu yok',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    var exams = studentData!['exams'] as List;
    var lastExams = exams.take(6).toList().reversed.toList();

    double maxScoreInData = lastExams.fold(0.0, (max, exam) {
      double score = (exam['lgsScore'] ?? 0).toDouble();
      return score > max ? score : max;
    });
    double chartMaxScore = maxScoreInData > 0 ? maxScoreInData * 1.1 : 500;

    return Container(
      height: 280,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.blue[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Son ${lastExams.length} Genel Deneme Performansı',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: lastExams.isEmpty
                ? Center(
                    child: Text(
                      'Grafik için yeterli veri yok',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: lastExams.asMap().entries.map((entry) {
                      int index = entry.key;
                      var exam = entry.value;

                      double score = (exam['lgsScore'] ?? 0).toDouble();
                      int totalNet = exam['totalNet'] ?? 0;
                      double heightRatio = chartMaxScore > 0
                          ? (score / chartMaxScore).clamp(0.05, 1.0)
                          : 0.05;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (score > 0) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${score.toInt()}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],
                              Container(
                                width: double.infinity,
                                height: (160 * heightRatio).clamp(8.0, 160.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: score > 0
                                        ? [Colors.blue[600]!, Colors.blue[400]!]
                                        : [
                                            Colors.grey[400]!,
                                            Colors.grey[300]!,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Net: $totalNet',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                exam['date']?.substring(0, 5) ?? '',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // YENİ: Ders denemeleri grafiği
  Widget _buildSubjectExamChart() {
    if (studentData == null || studentData!['subjectExams'].isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                'Henüz ders denemesi sonucu yok',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    var subjectExams = studentData!['subjectExams'] as List;
    var lastSubjectExams = subjectExams.take(8).toList().reversed.toList();

    final Map<String, Color> _subjectColors = {
      'matematik': Colors.blue,
      'fen': Colors.green,
      'turkce': Colors.red,
      'din': Colors.purple,
      'ingilizce': Colors.orange,
      'inkilap': Colors.teal,
    };

    return Container(
      height: 280,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.indigo[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Son ${lastSubjectExams.length} Ders Denemesi Performansı',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: lastSubjectExams.isEmpty
                ? Center(
                    child: Text(
                      'Grafik için yeterli veri yok',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: lastSubjectExams.asMap().entries.map((entry) {
                      int index = entry.key;
                      var exam = entry.value;

                      double net = (exam['net'] ?? 0).toDouble();
                      int maxQuestions = exam['maxQuestions'] ?? 20;
                      String subject = exam['subject'] ?? '';
                      Color subjectColor =
                          _subjectColors[subject] ?? Colors.grey;

                      double heightRatio = maxQuestions > 0
                          ? (net / maxQuestions).clamp(0.05, 1.0)
                          : 0.05;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (net > 0) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: subjectColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    net.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],
                              Container(
                                width: double.infinity,
                                height: (160 * heightRatio).clamp(8.0, 160.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      subjectColor,
                                      subjectColor.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                _getSubjectShort(subject),
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    var info = widget.student;

    return Scaffold(
      appBar: AppBar(
        title: Text(info['name']),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Portfolio yükleniyor...'),
                ],
              ),
            )
          : studentData == null
          ? Center(child: Text('Veri yüklenemedi'))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Öğrenci header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Text(
                            info['name'].substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info['name'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Okul No: ${info['schoolNo']}',
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
                  SizedBox(height: 20),

                  // İstatistik kartları - İYİLEŞTİRİLDİ
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Üst sıra
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Genel\nDeneme',
                                '${(studentData!['exams'] as List).length}',
                                Colors.purple[600]!,
                                Icons.quiz,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Ders\nDenemesi',
                                '${(studentData!['subjectExams'] as List).length}',
                                Colors.indigo[600]!,
                                Icons.school,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Okunan\nKitap',
                                '${(studentData!['books'] as List).where((b) => b['status'] == 'okudu').length}',
                                Colors.green[600]!,
                                Icons.book,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Alt sıra
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Haftalık\nKayıt',
                                '${(studentData!['weekly'] as List).length}',
                                Colors.orange[600]!,
                                Icons.assignment,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Devamsızlık',
                                '${(studentData!['attendance'] as List).length}',
                                Colors.red[600]!,
                                Icons.person_off,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Container()), // Boş alan
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Genel deneme grafiği
                  _buildExamChart(),
                  SizedBox(height: 20),

                  // YENİ: Ders denemeleri grafiği
                  _buildSubjectExamChart(),
                  SizedBox(height: 20),

                  // Detaylar için tablar - GÜNCELLENDİ
                  DefaultTabController(
                    length: 5, // 4'ten 5'e çıkardık
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            isScrollable: true, // Scroll yapılabilir yaptık
                            labelColor: Colors.blue[700],
                            unselectedLabelColor: Colors.grey[600],
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tabs: [
                              Tab(text: 'Genel\nDenemeler'),
                              Tab(text: 'Ders\nDenemeleri'), // YENİ EKLENEN
                              Tab(text: 'Kitaplar'),
                              Tab(text: 'Haftalık'),
                              Tab(text: 'Devamsızlık'),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TabBarView(
                            children: [
                              _buildExamsList(studentData!['exams']),
                              _buildSubjectExamsList(
                                studentData!['subjectExams'],
                              ), // YENİ EKLENEN
                              _buildBooksList(studentData!['books']),
                              _buildWeeklyList(studentData!['weekly']),
                              _buildAttendanceList(studentData!['attendance']),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Tab içerikleri için yardımcı metodlar
  Widget _buildExamsList(List exams) {
    if (exams.isEmpty) {
      return Center(child: Text('Henüz genel deneme sonucu yok'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        var exam = exams[index];
        return ListTile(
          leading: Icon(Icons.quiz, color: Colors.purple[600]),
          title: Text(exam['name'] ?? 'Deneme'),
          subtitle: Text('Tarih: ${exam['date'] ?? ''}'),
          trailing: Text('${(exam['lgsScore'] ?? 0).toInt()}'),
        );
      },
    );
  }

  // YENİ: Ders denemeleri listesi
  Widget _buildSubjectExamsList(List subjectExams) {
    if (subjectExams.isEmpty) {
      return Center(child: Text('Henüz ders denemesi sonucu yok'));
    }

    final Map<String, Color> _subjectColors = {
      'matematik': Colors.blue,
      'fen': Colors.green,
      'turkce': Colors.red,
      'din': Colors.purple,
      'ingilizce': Colors.orange,
      'inkilap': Colors.teal,
    };

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: subjectExams.length,
      itemBuilder: (context, index) {
        var exam = subjectExams[index];
        Color subjectColor = _subjectColors[exam['subject']] ?? Colors.grey;

        return ListTile(
          leading: Icon(Icons.school, color: subjectColor),
          title: Text(exam['examName'] ?? 'Ders Denemesi'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${exam['subjectName']} - ${exam['examDate']}'),
              Text('D:${exam['dogru']} Y:${exam['yanlis']} B:${exam['bos']}'),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: subjectColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Net: ${(exam['net'] ?? 0).toStringAsFixed(1)}',
              style: TextStyle(
                color: subjectColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          isThreeLine: true,
        );
      },
    );
  }

  Widget _buildBooksList(List books) {
    if (books.isEmpty) {
      return Center(child: Text('Henüz kitap eklenmemiş'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        var book = books[index];
        return ListTile(
          leading: Icon(Icons.book, color: Colors.green[600]),
          title: Text(book['title'] ?? 'Kitap'),
          subtitle: Text('Yazar: ${book['author'] ?? ''}'),
          trailing: Text(book['status'] ?? ''),
        );
      },
    );
  }

  Widget _buildWeeklyList(List weekly) {
    if (weekly.isEmpty) {
      return Center(child: Text('Henüz haftalık kayıt yok'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: weekly.length,
      itemBuilder: (context, index) {
        var week = weekly[index];
        int total =
            (week['turkce'] ?? 0) +
            (week['matematik'] ?? 0) +
            (week['fen'] ?? 0) +
            (week['ingilizce'] ?? 0) +
            (week['din'] ?? 0) +
            (week['inkilap'] ?? 0);
        return ListTile(
          leading: Icon(Icons.assignment, color: Colors.orange[600]),
          title: Text('Hafta: ${week['week'] ?? ''}'),
          trailing: Text('$total soru'),
        );
      },
    );
  }

  Widget _buildAttendanceList(List attendance) {
    if (attendance.isEmpty) {
      return Center(child: Text('Devamsızlık kaydı yok'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: attendance.length,
      itemBuilder: (context, index) {
        var absent = attendance[index];
        return ListTile(
          leading: Icon(Icons.person_off, color: Colors.red[600]),
          title: Text('Devamsızlık'),
          trailing: Text(absent['date'] ?? ''),
        );
      },
    );
  }
}
