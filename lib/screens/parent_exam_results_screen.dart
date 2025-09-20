import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentExamResultsScreen extends StatefulWidget {
  final String parentUsername;

  const ParentExamResultsScreen({Key? key, required this.parentUsername})
    : super(key: key);

  @override
  _ParentExamResultsScreenState createState() =>
      _ParentExamResultsScreenState();
}

class _ParentExamResultsScreenState extends State<ParentExamResultsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> exams = [];

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  void _fetchExams() async {
    try {
      var parentDoc = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .get();
      if (!parentDoc.exists) return;

      var student = parentDoc['student'];
      var examsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('students')
          .doc(student['name'])
          .collection('exams')
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> tempExams = examsSnapshot.docs.map((doc) {
        var data = doc.data();

        Map<String, int> dersNetleri = {};
        List<String> dersler = [
          'turkce',
          'matematik',
          'fen',
          'inkilap',
          'din',
          'ingilizce',
        ];
        dersler.forEach((ders) {
          int dogru = data[ders]['dogru'] ?? 0;
          int yanlis = data[ders]['yanlis'] ?? 0;
          dersNetleri[ders] = dogru - (yanlis ~/ 3);
        });

        double puan =
            (dersNetleri['turkce']! * 4.2538) +
            (dersNetleri['inkilap']! * 1.666) +
            (dersNetleri['din']! * 1.899) +
            (dersNetleri['ingilizce']! * 1.5075) +
            (dersNetleri['matematik']! * 4.348) +
            (dersNetleri['fen']! * 4.123) +
            194.752082;

        int toplamNet = dersNetleri.values.reduce((a, b) => a + b);

        return {
          'name': data['name'],
          'date': data['date'],
          'dersNetleri': dersNetleri,
          'toplamNet': toplamNet,
          'puan': puan,
          'rawDers': data,
        };
      }).toList();

      setState(() {
        exams = tempExams;
      });
    } catch (e) {
      print('Error fetching exams: $e');
    }
  }

  Widget _buildDersRow(String dersAdi, Map<String, dynamic> dersData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dersAdi, style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: Text('Doğru: ${dersData['dogru'] ?? 0}')),
            Expanded(child: Text('Yanlış: ${dersData['yanlis'] ?? 0}')),
            Expanded(
              child: Text(
                'Net: ${dersData['dogru'] != null ? dersData['dogru'] - (dersData['yanlis'] ~/ 3) : 0}',
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deneme Sınavı Sonuçları')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: exams.isEmpty
            ? Center(child: Text('Henüz deneme sonucu yok'))
            : ListView.builder(
                itemCount: exams.length,
                itemBuilder: (context, index) {
                  var exam = exams[index];
                  var dersler = exam['dersNetleri'] as Map<String, int>;
                  var rawDers = exam['rawDers'] as Map<String, dynamic>;
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${exam['name']} - ${exam['date']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Divider(),
                          _buildDersRow('Türkçe', rawDers['turkce'] ?? {}),
                          _buildDersRow(
                            'Matematik',
                            rawDers['matematik'] ?? {},
                          ),
                          _buildDersRow('Fen Bilimleri', rawDers['fen'] ?? {}),
                          _buildDersRow(
                            'İnkılap Tarihi',
                            rawDers['inkilap'] ?? {},
                          ),
                          _buildDersRow('Din Kültürü', rawDers['din'] ?? {}),
                          _buildDersRow(
                            'İngilizce',
                            rawDers['ingilizce'] ?? {},
                          ),
                          Divider(),
                          Text('Toplam Net: ${exam['toplamNet']}'),
                          Text(
                            'Yaklaşık LGS Puanı: ${exam['puan'].toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
