import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIAnalysisScreen extends StatefulWidget {
  final String parentUsername;

  const AIAnalysisScreen({super.key, required this.parentUsername});

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _canUseAI = true;
  String? _lastAnalysis;
  int _currentUsageCount = 0;
  int _maxUsagePerMonth = 2; // Ayda 2 kez kullanım hakkı

  @override
  void initState() {
    super.initState();
    _checkUsageLimit();
  }

  void _checkUsageLimit() async {
    try {
      var doc = await _db.collection('users').doc(widget.parentUsername).get();
      var data = doc.data() ?? {};

      print('AI Usage check - User data keys: ${data.keys}'); // Debug log

      DateTime now = DateTime.now();
      int currentMonth = now.month;
      int currentYear = now.year;

      // Mevcut ay ve yıl bilgisi
      int? storedMonth = data['aiUsageMonth'];
      int? storedYear = data['aiUsageYear'];
      int usageCount = data['aiUsageCount'] ?? 0;

      print(
        'Current: $currentYear/$currentMonth, Stored: $storedYear/$storedMonth, Count: $usageCount',
      ); // Debug

      // Yeni ay başladı mı kontrol et
      if (storedMonth != currentMonth || storedYear != currentYear) {
        // Yeni ay, kullanım sayısını sıfırla
        await _resetMonthlyUsage();
        usageCount = 0;
        print('New month detected, usage count reset'); // Debug
      }

      setState(() {
        _currentUsageCount = usageCount;
        _canUseAI = usageCount < _maxUsagePerMonth;
      });

      print(
        'Can use AI: $_canUseAI, Usage: $usageCount/$_maxUsagePerMonth',
      ); // Debug

      // Son analiz varsa göster
      if (data['lastAIAnalysis'] != null) {
        setState(() {
          _lastAnalysis = data['lastAIAnalysis'];
        });
      }
    } catch (e) {
      print('Error checking usage: $e');
      // Hata durumunda AI kullanımına izin ver
      setState(() {
        _canUseAI = true;
        _currentUsageCount = 0;
      });
    }
  }

  // Aylık kullanım sayısını sıfırla
  Future<void> _resetMonthlyUsage() async {
    try {
      DateTime now = DateTime.now();
      await _db.collection('users').doc(widget.parentUsername).update({
        'aiUsageCount': 0,
        'aiUsageMonth': now.month,
        'aiUsageYear': now.year,
      });
      print('Monthly usage reset completed');
    } catch (e) {
      print('Error resetting monthly usage: $e');
    }
  }

  // Debug için AI kullanım durumunu sıfırla
  Future<void> _resetAIUsage() async {
    try {
      await _db.collection('users').doc(widget.parentUsername).update({
        'aiUsageCount': FieldValue.delete(),
        'aiUsageMonth': FieldValue.delete(),
        'aiUsageYear': FieldValue.delete(),
        'lastAIAnalysis': FieldValue.delete(),
        // Eski sistem alanlarını da temizle
        'lastAIUsage': FieldValue.delete(),
      });

      setState(() {
        _canUseAI = true;
        _currentUsageCount = 0;
        _lastAnalysis = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI kullanım durumu sıfırlandı')));

      print('AI usage data reset completed');
    } catch (e) {
      print('Error resetting AI usage: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sıfırlama hatası: $e')));
    }
  }

  Future<String> _getStudentDataForAI() async {
    try {
      // Öğrenci bilgileri
      var userDoc = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .get();
      var student = userDoc.data()?['student'] ?? {};

      // Son 5 deneme
      var examsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('exams')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      // Son haftalık veriler
      var weeklySnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('weekly_questions')
          .orderBy('week', descending: true)
          .limit(4)
          .get();

      // Kitap verileri
      var booksSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('books')
          .get();

      // Veriyi düzenle
      String dataText =
          '''
Öğrenci: ${student['name']} (Okul No: ${student['schoolNo']})

DENEME SONUÇLARI:
''';

      for (var exam in examsSnapshot.docs) {
        var data = exam.data();
        dataText +=
            '''
${data['name']}: LGS Puanı ${(data['lgsScore'] ?? 0).toInt()}, Toplam Net: ${data['totalNet'] ?? 0}
Dersler - Türkçe: ${_getNetFromExam(data, 'turkce')}, Matematik: ${_getNetFromExam(data, 'matematik')}, 
Fen: ${_getNetFromExam(data, 'fen')}, İnkılap: ${_getNetFromExam(data, 'inkilap')}, 
Din: ${_getNetFromExam(data, 'din')}, İngilizce: ${_getNetFromExam(data, 'ingilizce')}
''';
      }

      dataText += '\nHAFTALIK SORU SAYILARI:\n';
      for (var week in weeklySnapshot.docs) {
        var data = week.data();
        int total =
            (data['turkce'] ?? 0) +
            (data['matematik'] ?? 0) +
            (data['fen'] ?? 0) +
            (data['ingilizce'] ?? 0) +
            (data['din'] ?? 0) +
            (data['inkilap'] ?? 0);
        dataText += 'Hafta ${data['week']}: $total soru\n';
      }

      dataText += '\nKİTAP OKUMA:\n';
      int okudu = 0, okuyor = 0;
      for (var book in booksSnapshot.docs) {
        var data = book.data();
        if (data['status'] == 'okudu') okudu++;
        if (data['status'] == 'okuyor') okuyor++;
      }
      dataText += 'Okunan kitap: $okudu, Şu an okuyor: $okuyor\n';

      return dataText;
    } catch (e) {
      print('Error getting student data: $e');
      return 'Veri alınamadı';
    }
  }

  int _getNetFromExam(Map<String, dynamic> exam, String subject) {
    if (exam[subject] == null) return 0;
    int dogru = exam[subject]['dogru'] ?? 0;
    int yanlis = exam[subject]['yanlis'] ?? 0;
    int net = dogru - (yanlis ~/ 3);
    return net < 0 ? 0 : net;
  }

  Future<String> _callZAI(String studentData) async {
    try {
      // Z.ai'nin doğru API endpoint'i
      const String apiUrl = 'https://api.z.ai/api/paas/v4/chat/completions';
      const String apiKey = '423ff24473d84d6ab9c1f39525e23ff5.hzSsBwHuiWMsOVMC';

      print('Making AI API call to: $apiUrl'); // Debug log

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'Accept-Language': 'tr-TR,tr', // Türkçe yanıt için
        },
        body: jsonEncode({
          'model': 'glm-4', // Z.ai'nin modeli
          'messages': [
            {
              'role': 'system',
              'content':
                  '''Sen bir LGS danışmanısın. Öğrencinin verilerini analiz edip 
detaylı bir değerlendirme yapacaksın. Güçlü ve zayıf yönlerini belirt, 
gelişim önerilerinde bulun ve motivasyonel tavsiyelerde bulun. 
Türkçe yanıt ver ve veliler için anlaşılır ol. Analizi şu başlıklar altında yap:

1. GENEL DURUM ÖZETI
2. GÜÇLÜ YÖNLER
3. GELİŞTİRİLMESİ GEREKEN ALANLAR
4. ÖNERİLER
5. MOTİVASYON MESAJI''',
            },
            {
              'role': 'user',
              'content':
                  'Bu öğrencinin LGS deneme sonuçlarını ve genel durumunu analiz et:\n\n$studentData',
            },
          ],
          'max_tokens': 1500,
          'temperature': 0.7,
        }),
      );

      print('API Response Status: ${response.statusCode}'); // Debug log
      print('API Response Body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'];
        } else {
          return 'AI yanıtı beklenmeyen formatta geldi. Lütfen tekrar deneyin.';
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return 'AI analizi sırasında hata oluştu (Kod: ${response.statusCode}). Lütfen API anahtarınızı kontrol edin ve tekrar deneyin.';
      }
    } catch (e) {
      print('AI API Error: $e');
      return 'AI analizi sırasında bağlantı hatası oluştu. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.';
    }
  }

  void _requestAnalysis() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Öğrenci verilerini topla
      String studentData = await _getStudentDataForAI();

      // AI analizini çağır
      String analysis = await _callZAI(studentData);

      // Kullanım sayısını artır ve analizi kaydet
      DateTime now = DateTime.now();
      int newUsageCount = _currentUsageCount + 1;

      await _db.collection('users').doc(widget.parentUsername).update({
        'lastAIAnalysis': analysis,
        'aiUsageCount': newUsageCount,
        'aiUsageMonth': now.month,
        'aiUsageYear': now.year,
        'lastAIUsageDate': FieldValue.serverTimestamp(),
      });

      setState(() {
        _lastAnalysis = analysis;
        _currentUsageCount = newUsageCount;
        _canUseAI = newUsageCount < _maxUsagePerMonth;
        _isLoading = false;
      });

      print(
        'AI analysis completed. New usage count: $newUsageCount/$_maxUsagePerMonth',
      );
    } catch (e) {
      print('Error requesting analysis: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analiz sırasında hata oluştu: $e')),
      );
    }
  }

  String _getUsageStatusText() {
    if (_currentUsageCount == 0) {
      return 'Bu ay henüz AI analizi kullanmadınız. $_maxUsagePerMonth kullanım hakkınız var.';
    } else if (_currentUsageCount < _maxUsagePerMonth) {
      int remaining = _maxUsagePerMonth - _currentUsageCount;
      return 'Bu ay $_currentUsageCount kez kullandınız. $remaining kullanım hakkınız daha var.';
    } else {
      return 'Bu ay $_maxUsagePerMonth kullanım hakkınızı tamamladınız. Yeni kullanım için gelecek ayı bekleyin.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Öğrenci Analizi'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          // Debug için sıfırlama butonu (geliştirme aşamasında)
          IconButton(
            onPressed: _resetAIUsage,
            icon: Icon(Icons.refresh),
            tooltip: 'AI Kullanımını Sıfırla (Debug)',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.purple[700]),
                        SizedBox(width: 8),
                        Text(
                          'AI Öğrenci Analizi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Yapay zeka öğrencinizin deneme sonuçlarını, haftalık çalışma verilerini ve okuma alışkanlıklarını analiz ederek kişiselleştirilmiş tavsiyelerde bulunur.',
                      style: TextStyle(color: Colors.purple[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Aylık $_maxUsagePerMonth kullanım hakkınız var\n• Analiz 2-3 dakika sürebilir\n• Kişiselleştirilmiş öneriler alırsınız',
                      style: TextStyle(fontSize: 12, color: Colors.purple[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Kullanım durumu kartı
            Card(
              color: _canUseAI ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _canUseAI ? Icons.check_circle : Icons.info,
                      color: _canUseAI ? Colors.green[700] : Colors.orange[700],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kullanım Durumu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _canUseAI
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                          Text(
                            _getUsageStatusText(),
                            style: TextStyle(
                              fontSize: 13,
                              color: _canUseAI
                                  ? Colors.green[700]
                                  : Colors.orange[700],
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

            if (_canUseAI) ...[
              Center(
                child: _isLoading
                    ? Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('AI öğrencinizi analiz ediyor...'),
                          SizedBox(height: 8),
                          Text(
                            'Bu işlem 2-3 dakika sürebilir',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: _requestAnalysis,
                        icon: Icon(Icons.psychology),
                        label: Text('AI Analizi Başlat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 20),
            ],

            if (_lastAnalysis != null) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.purple[700]),
                            SizedBox(width: 8),
                            Text(
                              'AI Analiz Raporu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700],
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_currentUsageCount/$_maxUsagePerMonth',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _lastAnalysis!,
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (!_isLoading && !_canUseAI) ...[
              Expanded(
                child: Center(
                  child: Text(
                    'Bu ay için AI analizi kullanım hakkınız doldu.\nYeni kullanım için gelecek ayı bekleyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
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
