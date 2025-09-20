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
  String? selectedStudentId;
  Map<String, dynamic>? studentData;
  bool _isLoading = false;

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
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  void _loadStudentPortfolio(String parentId) async {
    setState(() {
      _isLoading = true;
      selectedStudentId = parentId;
    });

    try {
      // Öğrenci temel bilgileri
      var userDoc = await _db.collection('users').doc(parentId).get();
      var userData = userDoc.data() ?? {};

      // Deneme sonuçları
      var examsSnapshot = await _db
          .collection('users')
          .doc(parentId)
          .collection('exams')
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamChart() {
    if (studentData == null || studentData!['exams'].isEmpty) {
      return Container();
    }

    var exams = studentData!['exams'] as List;
    var lastExams = exams.take(5).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son 5 Deneme Sonucu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: lastExams.length,
                itemBuilder: (context, index) {
                  var exam = lastExams[index];
                  double score = (exam['lgsScore'] ?? 0).toDouble();
                  int totalNet = exam['totalNet'] ?? 0;

                  return Container(
                    width: 80,
                    margin: EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 40,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Container(
                                width: 40,
                                height: (score / 500) * 150,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${score.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Net: $totalNet', style: TextStyle(fontSize: 10)),
                        Text(
                          exam['name'] ?? '',
                          style: TextStyle(fontSize: 8),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioView() {
    if (studentData == null) return Container();

    var info = studentData!['info'] as Map<String, dynamic>;
    var exams = studentData!['exams'] as List;
    var books = studentData!['books'] as List;
    var weekly = studentData!['weekly'] as List;
    var attendance = studentData!['attendance'] as List;

    // İstatistikler
    int totalExams = exams.length;
    int totalBooks = books.length;
    int booksRead = books.where((b) => b['status'] == 'okudu').length;
    int totalAbsent = attendance.length;

    double avgScore = 0;
    if (exams.isNotEmpty) {
      double totalScore = exams.fold(
        0,
        (sum, exam) => sum + (exam['lgsScore'] ?? 0),
      );
      avgScore = totalScore / exams.length;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Öğrenci Bilgileri
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['name'] ?? 'Bilinmiyor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Okul No: ${info['schoolNo'] ?? 'Bilinmiyor'}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // İstatistik Kartları
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildStatCard(
                'Toplam\nDeneme',
                '$totalExams',
                Colors.purple,
                Icons.quiz,
              ),
              _buildStatCard(
                'Ortalama\nPuan',
                '${avgScore.toInt()}',
                Colors.blue,
                Icons.trending_up,
              ),
              _buildStatCard(
                'Okunan\nKitap',
                '$booksRead/$totalBooks',
                Colors.green,
                Icons.book,
              ),
              _buildStatCard(
                'Devamsızlık',
                '$totalAbsent',
                Colors.red,
                Icons.person_off,
              ),
            ],
          ),
          SizedBox(height: 16),

          // Grafik
          _buildExamChart(),
          SizedBox(height: 16),

          // Detaylar
          DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue[700],
                  tabs: [
                    Tab(text: 'Denemeler'),
                    Tab(text: 'Kitaplar'),
                    Tab(text: 'Haftalık'),
                    Tab(text: 'Devamsızlık'),
                  ],
                ),
                Container(
                  height: 300,
                  child: TabBarView(
                    children: [
                      // Denemeler Tab
                      ListView.builder(
                        itemCount: exams.length,
                        itemBuilder: (context, index) {
                          var exam = exams[index];
                          return ListTile(
                            title: Text(exam['name'] ?? 'Deneme'),
                            subtitle: Text('Tarih: ${exam['date'] ?? ''}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${(exam['lgsScore'] ?? 0).toInt()}'),
                                Text('Net: ${exam['totalNet'] ?? 0}'),
                              ],
                            ),
                          );
                        },
                      ),
                      // Kitaplar Tab
                      ListView.builder(
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          var book = books[index];
                          return ListTile(
                            title: Text(book['title'] ?? 'Kitap'),
                            subtitle: Text('Yazar: ${book['author'] ?? ''}'),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: book['status'] == 'okudu'
                                    ? Colors.green[100]
                                    : Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                book['status'] ?? '',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                      // Haftalık Tab
                      ListView.builder(
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
                            title: Text('Hafta: ${week['week'] ?? ''}'),
                            subtitle: Text('Toplam $total soru'),
                            trailing: Text(week['enteredBy'] ?? ''),
                          );
                        },
                      ),
                      // Devamsızlık Tab
                      ListView.builder(
                        itemCount: attendance.length,
                        itemBuilder: (context, index) {
                          var absent = attendance[index];
                          return ListTile(
                            title: Text('Devamsızlık'),
                            subtitle: Text(absent['date'] ?? ''),
                            leading: Icon(Icons.person_off, color: Colors.red),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      ),
      body: Row(
        children: [
          // Sol panel - Öğrenci listesi
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Öğrenci Listesi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var student = students[index];
                      bool isSelected =
                          selectedStudentId == student['parentId'];

                      return Container(
                        color: isSelected ? Colors.blue[100] : null,
                        child: ListTile(
                          title: Text(student['name']),
                          subtitle: Text('No: ${student['schoolNo']}'),
                          onTap: () =>
                              _loadStudentPortfolio(student['parentId']),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Sağ panel - Portfolio detayı
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : selectedStudentId == null
                ? Center(child: Text('Bir öğrenci seçin'))
                : _buildPortfolioView(),
          ),
        ],
      ),
    );
  }
}
