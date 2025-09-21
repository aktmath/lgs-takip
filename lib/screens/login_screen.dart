import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode için YENİ EKLENEN
import 'home_screen.dart';
import '../services/firestore_services.dart';
import '../services/fcm_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  // Login başarılı olduktan sonra FCM token kaydet
  Future<void> _onLoginSuccess(String username) async {
    try {
      // FCM token'ı kullanıcı için kaydet
      await FCMServices.saveTokenToFirestore(username);

      // Okunmamış bildirim sayısını güncelle
      int unreadCount = await FCMServices.getUnreadNotificationCount(username);

      print('Login successful for: $username');
      print('Unread notifications: $unreadCount');
      print('FCM token saved to Firestore');

      // Home screen'a geçiş yap
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
      );
    } catch (e) {
      print('Error during login success: $e');
      // Yine de home screen'a git, FCM sorunu login'i engellemsin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
      );
    }
  }

  void _login() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı ve şifre boş bırakılamaz')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await FirestoreServices.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        // Login başarılı - FCM token kaydet ve home screen'a git
        await _onLoginSuccess(_usernameController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı adı veya şifre hatalı')),
        );
      }
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giriş yapılırken hata oluştu')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // FCM Test fonksiyonu
  void _testFCM() async {
    try {
      await FCMServices.sendTestNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'FCM Token konsola yazıldı. Test bildirimi gönderildi.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('FCM Test hatası: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E8B57), // Deniz yeşili
              Color(0xFF20B2AA), // Açık deniz yeşili
              Color(0xFF4682B4), // Çelik mavisi
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ÖZEL LOGONUZ
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/app_logo.png', // Logonuz buraya
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Logo yoksa fallback icon
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.school,
                              size: 64,
                              color: Color(0xFF2E8B57),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(
                    '8B LGS Takip',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Öğrenci ve Veli Paneli',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 48),
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Giriş Yap',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 32),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Kullanıcı Adı',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.person),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2E8B57),
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF2E8B57),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        // FCM Test Butonu - SADECE DEBUG MODE'DA GÖSTER
                        if (kDebugMode) ...[
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: _testFCM,
                              icon: Icon(Icons.notifications_active, size: 20),
                              label: Text('FCM Test (Debug)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Color(0xFF2E8B57),
                                side: BorderSide(color: Color(0xFF2E8B57)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '8B LGS Takip Sistemi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Kullanıcı adı ve şifre ile giriş yapın.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Programı yapan: Abdulkadir TIRAŞ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
