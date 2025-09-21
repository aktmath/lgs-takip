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

  // --- GEMINI API BİLGİLERİ ---
  // Buraya kendi API anahtarınızı yapıştırın
  final String _geminiApiKey = 'AIzaSyCXdQ3o4rMHga9xWgILwV968UVG8wCeyyk';
  final String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=';

  @override
  void initState() {
    super.initState();
    _checkUsageLimit();
  }

  void _checkUsageLimit() async {
    try {
      var doc = await _db.collection('users').doc(widget.parentUsername).get();
      var data = doc.data() ?? {};

      DateTime now = DateTime.now();
      int currentMonth = now.month;
      int currentYear = now.year;

      int? storedMonth = data['aiUsageMonth'];
      int? storedYear = data['aiUsageYear'];
      int usageCount = data['aiUsageCount'] ?? 0;

      if (storedMonth != currentMonth || storedYear != currentYear) {
        await _resetMonthlyUsage();
        usageCount = 0;
      }

      setState(() {
        _currentUsageCount = usageCount;
        _canUseAI = usageCount < _maxUsagePerMonth;
      });

      if (data['lastAIAnalysis'] != null) {
        setState(() {
          _lastAnalysis = data['lastAIAnalysis'];
        });
      }
    } catch (e) {
      print('Error checking usage: $e');
      setState(() {
        _canUseAI = true;
        _currentUsageCount = 0;
      });
    }
  }

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

  Future<void> _adminResetAIUsage() async {
    try {
      await _db.collection('users').doc(widget.parentUsername).update({
        'aiUsageCount': FieldValue.delete(),
        'aiUsageMonth': FieldValue.delete(),
        'aiUsageYear': FieldValue.delete(),
        'lastAIAnalysis': FieldValue.delete(),
        'lastAIUsage': FieldValue.delete(),
      });

      setState(() {
        _canUseAI = true;
        _currentUsageCount = 0;
        _lastAnalysis = null;
      });

      print('AI usage data reset by admin');
    } catch (e) {
      print('Error resetting AI usage: $e');
    }
  }

  Future<String> _getStudentDataForAI() async {
    try {
      var userDoc = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .get();
      var student = userDoc.data()?['student'] ?? {};

      // Genel deneme sonuçları
      var examsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('exams')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      // YENİ: Ders denemeleri sonuçları - GENİŞLETİLDİ
      var subjectExamsSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('subject_exams')
          .orderBy('timestamp', descending: true)
          .limit(15) // Daha fazla veri al
          .get();

      var weeklySnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('weekly_questions')
          .orderBy('week', descending: true)
          .limit(4)
          .get();

      var booksSnapshot = await _db
          .collection('users')
          .doc(widget.parentUsername)
          .collection('books')
          .get();

      String dataText =
          '''
Öğrenci: ${student['name']} (Okul No: ${student['schoolNo']})

GENEL LGS DENEME SONUÇLARI:
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

      // YENİ: Ders denemeleri analizi - ÇOK DAHA DETAYLI
      dataText +=
          '\nDERS BAZINDA DENEME SONUÇLARI (ÇOK ÖNEMLİ - DETAYLI ANALİZ):\n';

      // Ders denemeleri için derse göre grupla ve analiz et
      Map<String, List<Map<String, dynamic>>> subjectExamsBySubject = {};
      for (var subjectExam in subjectExamsSnapshot.docs) {
        var data = subjectExam.data();
        String subject = data['subject'] ?? '';
        String subjectName = data['subjectName'] ?? '';

        if (!subjectExamsBySubject.containsKey(subject)) {
          subjectExamsBySubject[subject] = [];
        }
        subjectExamsBySubject[subject]!.add(data);
      }

      for (var entry in subjectExamsBySubject.entries) {
        String subject = entry.key;
        List<Map<String, dynamic>> exams = entry.value;
        String subjectName = exams.isNotEmpty
            ? (exams.first['subjectName'] ?? subject)
            : subject;

        dataText += '\n=== $subjectName Dersi Detaylı Analizi ===\n';
        dataText += 'Toplam ${exams.length} deneme yapılmış.\n';

        double totalNet = 0;
        double totalDogruRate = 0;
        double totalYanlisRate = 0;
        double totalBosRate = 0;
        int maxQuestions = exams.isNotEmpty
            ? (exams.first['maxQuestions'] ?? 20)
            : 20;

        for (var exam in exams) {
          double net = exam['net']?.toDouble() ?? 0.0;
          int dogru = exam['dogru'] ?? 0;
          int yanlis = exam['yanlis'] ?? 0;
          int bos = exam['bos'] ?? 0;

          totalNet += net;
          totalDogruRate += (dogru / maxQuestions) * 100;
          totalYanlisRate += (yanlis / maxQuestions) * 100;
          totalBosRate += (bos / maxQuestions) * 100;

          dataText +=
              '- ${exam['examName']} (${exam['examDate']}): Net ${net.toStringAsFixed(2)} ';
          dataText +=
              '(D:${dogru}/%${((dogru / maxQuestions) * 100).toStringAsFixed(1)} ';
          dataText +=
              'Y:${yanlis}/%${((yanlis / maxQuestions) * 100).toStringAsFixed(1)} ';
          dataText +=
              'B:${bos}/%${((bos / maxQuestions) * 100).toStringAsFixed(1)})\n';
        }

        if (exams.isNotEmpty) {
          double averageNet = totalNet / exams.length;
          double avgDogruRate = totalDogruRate / exams.length;
          double avgYanlisRate = totalYanlisRate / exams.length;
          double avgBosRate = totalBosRate / exams.length;

          dataText += '\n$subjectName İstatistikleri:\n';
          dataText +=
              '- Ortalama Net: ${averageNet.toStringAsFixed(2)} / $maxQuestions\n';
          dataText += '- Başarı Oranı: %${avgDogruRate.toStringAsFixed(1)}\n';
          dataText +=
              '- Yanlış Yapma Oranı: %${avgYanlisRate.toStringAsFixed(1)}\n';
          dataText +=
              '- Boş Bırakma Oranı: %${avgBosRate.toStringAsFixed(1)}\n';

          // En iyi ve en kötü performansları bul
          exams.sort((a, b) => (b['net'] ?? 0).compareTo(a['net'] ?? 0));
          var bestExam = exams.first;
          var worstExam = exams.last;

          dataText +=
              '- En İyi Deneme: ${bestExam['examName']} (Net: ${bestExam['net']?.toStringAsFixed(2)})\n';
          dataText +=
              '- En Zayıf Deneme: ${worstExam['examName']} (Net: ${worstExam['net']?.toStringAsFixed(2)})\n';

          // Trend analizi
          if (exams.length >= 3) {
            var recentAvg =
                (exams
                    .take(3)
                    .fold(0.0, (sum, exam) => sum + (exam['net'] ?? 0))) /
                3;
            var olderAvg =
                (exams
                    .skip(3)
                    .fold(0.0, (sum, exam) => sum + (exam['net'] ?? 0))) /
                (exams.length - 3);

            if (recentAvg > olderAvg) {
              dataText +=
                  '- Trend: YUKARI YÖNLÜ (Son denemeler daha başarılı)\n';
            } else if (recentAvg < olderAvg) {
              dataText += '- Trend: AŞAĞI YÖNLÜ (Son denemeler daha zayıf)\n';
            } else {
              dataText += '- Trend: KARARLÅ (Stabil performans)\n';
            }
          }
        }

        dataText += '\n';
      }

      // Ders denemeleri vs Genel denemeler karşılaştırması
      dataText +=
          '\n=== DERS DENEMELERİ vs GENEL DENEMELER KARŞILAŞTIRMASI ===\n';
      dataText +=
          'Bu karşılaştırma ÇOK ÖNEMLİ - öğrencinin hangi derslerde güçlü/zayıf olduğunu ve ders odaklı çalışmanın etkisini gösterir.\n';

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

  // --- GÜNCEL GEMINI API ÇAĞRISI FONKSİYONU ---
  Future<String> _callGemini(String studentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_geminiApiUrl$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      '''Sen bir LGS danışmanısın ve LGS hakkında derinlemesine bilgiye sahipsin. Sınav yapısı, puan hesaplaması, lise türleri ve başarılı olmak için gereken stratejiler konusunda uzmansın.

İşte LGS'ye dair tüm bilmen gerekenler:
- LGS, sözel (50 soru) ve sayısal (40 soru) olmak üzere toplam 90 sorudan oluşur.
- Soru dağılımı:
    - Türkçe: 20 soru
    - Matematik: 20 soru
    - Fen Bilimleri: 20 soru
    - İnkılap Tarihi: 10 soru
    - Din Kültürü: 10 soru
    - İngilizce: 10 soru
- LGS puan hesaplamasında 3 yanlış 1 doğruyu götürür.
- Puanlar, derslerin ağırlık katsayılarına göre hesaplanır. Matematik ve Fen (2.0) dersleri, diğer sözel derslerden (1.0) daha yüksek katsayıya sahiptir. Bu, sayısal derslerin puanı daha çok etkilediği anlamına gelir.
- Öğrencinin deneme puanlarına göre Türkiye genelindeki yaklaşık yüzdelik dilimi ve bu dilimle gidilebilecek olası lise türleri (Fen Lisesi, Sosyal Bilimler Lisesi, Anadolu Lisesi vb.) hakkında tahmini bir yorum yap.

ÇOK ÖNEMLİ: Ders bazında deneme analizini ÇOK DETAYLI yapmak zorundasın. Bu denemelerdeki performansı genel deneme sonuçlarıyla karşılaştır ve hangi derslerde güçlü/zayıf olduğunu, ders odaklı çalışmanın etkisini, hangi derslerde daha fazla ders denemesi yapılması gerektiğini analiz et. Ders denemeleri öğrencinin gerçek potansiyelini daha iyi gösterir.

Analiz ve Koçluk Raporu Şablonu:
Aşağıdaki öğrenci verilerini bu uzmanlık bilginle analiz et ve veliler için anlaşılır, detaylı bir rapor oluştur.

1. GENEL DURUM ÖZETİ
   - Öğrencinin genel başarısını değerlendir.
   - Son deneme puanına göre gidebileceği olası lise türlerini belirt.
   - Ders bazında deneme performansını da dahil et ve bu ÇOK ÖNEMLİ.

2. GÜÇLÜ YÖNLER
   - Hangi derslerde başarılı olduğunu, netlerinin yüksek olduğu alanları açıkla.
   - Ders denemeleri ve genel denemeler arasındaki tutarlılığı değerlendir.
   - Ders odaklı deneme sonuçlarına özel vurgu yap.

3. GELİŞTİRİLMESİ GEREKEN ALANLAR
   - Hangi derslerde netleri düşükse, bu derslerdeki temel eksikliklere dikkat çek.
   - Özellikle sayısal derslerin önemine vurgu yap.
   - Ders denemeleri ile genel denemeler arasında farklılık varsa bunu belirt.
   - Hangi derslerde daha fazla ders denemesi yapılması gerektiğini söyle.

4. ÖNERİLER VE ÇALIŞMA STRATEJİSİ
   - Netlerini artırmak için kişiselleştirilmiş bir çalışma planı sun.
   - Ders bazında deneme sonuçlarını kullanarak hangi derslerde daha fazla ders denemesi yapılması gerektiğini öner.
   - Yanlışlarını kontrol etme süreci için bir yöntem öner (örneğin: yanlış defteri tutmak, yanlış soruların konularını tekrar etmek).
   - Deneme çözme stratejileri hakkında tavsiyelerde bulun (örneğin: zaman yönetimi, zor soruları atlama).
   - Ders bazlı deneme çözme sıklığı öner (hangi ders haftada kaç kez vs.).

5. MOTİVASYON MESAJI
   - Öğrenciye geleceğe yönelik, motive edici ve yapıcı bir mesaj ver.

Bu öğrencinin LGS deneme sonuçlarını, ders bazında deneme performansını ve genel durumunu analiz et:\n\n$studentData''',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          // Yanıt formatını kontrol et, eğer text yoksa hata fırlat
          if (data['candidates'][0]['content']['parts'][0]['text'] == null) {
            throw Exception('API response did not contain text content.');
          }
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'AI yanıtı beklenmeyen formatta geldi. Lütfen tekrar deneyin.';
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return 'AI analizi sırasında hata oluştu (Kod: ${response.statusCode}). Lütfen API anahtarınızı ve modelinizi kontrol edin.';
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
      String studentData = await _getStudentDataForAI();
      String analysis = await _callGemini(studentData);

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
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Admin Sıfırlama'),
                  content: Text('Bu işlemi yapmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Hayır'),
                    ),
                    TextButton(
                      onPressed: () {
                        _adminResetAIUsage();
                        Navigator.pop(context);
                      },
                      child: Text('Evet'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Sıfırlama (Geliştirici Kullanımı)',
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
                      'Yapay zeka öğrencinizin genel deneme sonuçları, ders bazında deneme performansları, haftalık çalışma verilerini ve okuma alışkanlıklarını analiz ederek kişiselleştirilmiş tavsiyelerde bulunur.',
                      style: TextStyle(color: Colors.purple[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Aylık $_maxUsagePerMonth kullanım hakkınız var\n• Analiz 2-3 dakika sürebilir\n• Hem genel hem de ders bazında analiz alırsınız\n• Kişiselleştirilmiş öneriler alırsınız\n• YENİ: Ders bazı deneme analizini dahil eder',
                      style: TextStyle(fontSize: 12, color: Colors.purple[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

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
