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
  bool _isLoading = true;

  final Map<String, String> _dersIsimleri = {
    'turkce': 'Türkçe',
    'matematik': 'Matematik',
    'fen': 'Fen Bilimleri',
    'inkilap': 'İnkılap Tarihi',
    'din': 'Din Kültürü',
    'ingilizce': 'İngilizce',
  };

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  void _fetchExams() async {
    try {
      var examsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('exams')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> tempExams = [];

      for (var doc in examsSnapshot.docs) {
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

        for (String ders in dersler) {
          if (data[ders] != null) {
            int dogru = data[ders]['dogru'] ?? 0;
            int yanlis = data[ders]['yanlis'] ?? 0;
            int net = dogru - (yanlis ~/ 3);
            dersNetleri[ders] = net < 0 ? 0 : net;
          } else {
            dersNetleri[ders] = 0;
          }
        }

        double lgsScore =
            (dersNetleri['turkce']! * 4.2538) +
            (dersNetleri['inkilap']! * 1.666) +
            (dersNetleri['din']! * 1.899) +
            (dersNetleri['ingilizce']! * 1.5075) +
            (dersNetleri['matematik']! * 4.348) +
            (dersNetleri['fen']! * 4.1230) +
            194.752082;

        int toplamNet = dersNetleri.values.reduce((a, b) => a + b);

        tempExams.add({
          'id': doc.id,
          'name': data['name'] ?? 'Bilinmiyor',
          'date': data['date'] ?? 'Tarih yok',
          'dersNetleri': dersNetleri,
          'toplamNet': toplamNet,
          'lgsScore': lgsScore,
          'rawData': data,
        });
      }

      setState(() {
        exams = tempExams;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching exams: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDersDetay(
    String dersAdi,
    Map<String, dynamic>? dersData,
    int net,
  ) {
    if (dersData == null) {
      return Container();
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dersAdi,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Doğru: ${dersData['dogru'] ?? 0}'),
              Text('Yanlış: ${dersData['yanlis'] ?? 0}'),
              Text('Boş: ${dersData['bos'] ?? 0}'),
            ],
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Net: $net',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          exam['name'],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarih: ${exam['date']}'),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Toplam Net: ${exam['toplamNet']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LGS: ${exam['lgsScore'].toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ders Detayları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 12),
                ..._dersIsimleri.entries.map((entry) {
                  String dersKey = entry.key;
                  String dersAdi = entry.value;
                  var dersData = exam['rawData'][dersKey];
                  int net = exam['dersNetleri'][dersKey] ?? 0;

                  return _buildDersDetay(dersAdi, dersData, net);
                }).toList(),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.purple.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Yaklaşık LGS Puanı',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${exam['lgsScore'].toStringAsFixed(2)} puan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toplam Net: ${exam['toplamNet']}',
                        style: TextStyle(color: Colors.grey.shade600),
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
        title: Text('Deneme Sonuçları'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : exams.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz, size: 64, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    'Henüz deneme sonucu yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Öğretmeninizin deneme sonuçlarını girmesini bekleyin',
                    style: TextStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (exams.isNotEmpty) ...[
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade100, Colors.purple.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Toplam Deneme',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              '${exams.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'En Yüksek Net',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              '${exams.map((e) => e['toplamNet']).reduce((a, b) => a > b ? a : b)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'En Yüksek Puan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                            Text(
                              '${exams.map((e) => e['lgsScore']).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      return _buildExamCard(exams[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
