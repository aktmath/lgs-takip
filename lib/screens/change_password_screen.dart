import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;

  const ChangePasswordScreen({
    Key? key,
    required this.username,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Yeni şifreler eşleşmiyor');
      return;
    }

    if (_newPasswordController.text == _currentPasswordController.text) {
      _showErrorSnackBar('Yeni şifre mevcut şifreden farklı olmalı');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Mevcut şifreyi kontrol et
      var userDoc = await _db.collection('users').doc(widget.username).get();

      if (!userDoc.exists) {
        _showErrorSnackBar('Kullanıcı bulunamadı');
        return;
      }

      var userData = userDoc.data()!;
      String currentPassword = userData['password'] ?? '';

      if (currentPassword != _currentPasswordController.text) {
        _showErrorSnackBar('Mevcut şifre hatalı');
        return;
      }

      // Şifreyi güncelle (Admin de dahil)
      await _db.collection('users').doc(widget.username).update({
        'password': _newPasswordController.text,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'passwordUpdatedBy': widget.username,
      });

      _showSuccessDialog();
    } catch (e) {
      print('Error changing password: $e');
      _showErrorSnackBar('Şifre değiştirilirken hata oluştu');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            SizedBox(width: 12),
            Text('Başarılı'),
          ],
        ),
        content: Text(
          'Şifreniz başarıyla değiştirildi. Güvenliğiniz için bu şifreyi kimseyle paylaşmayın.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dialog'u kapat
              Navigator.of(context).pop(); // Bu ekranı kapat
            },
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş olamaz';
    }
    if (value.length < 3) {
      return 'Şifre en az 3 karakter olmalı';
    }
    return null;
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator ?? _validatePassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
          prefixIcon: Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: onToggleVisibility,
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[600],
            ),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Şifre Değiştir'),
        backgroundColor: widget.isAdmin ? Colors.orange[700] : Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isAdmin
                ? [Colors.orange[700]!, Colors.orange[500]!]
                : [Colors.blue[700]!, Colors.blue[500]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                padding: EdgeInsets.all(32),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isAdmin
                              ? Colors.orange[100]
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.security,
                              size: 48,
                              color: widget.isAdmin
                                  ? Colors.orange[700]
                                  : Colors.blue[700],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Şifre Değiştir',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Kullanıcı: ${widget.username}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Mevcut şifre
                      _buildPasswordField(
                        controller: _currentPasswordController,
                        label: 'Mevcut Şifre',
                        hint: 'Şu anki şifrenizi girin',
                        obscureText: _obscureCurrentPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),

                      // Yeni şifre
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: 'Yeni Şifre',
                        hint: 'Yeni şifrenizi girin',
                        obscureText: _obscureNewPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),

                      // Şifre tekrar
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Yeni Şifre (Tekrar)',
                        hint: 'Yeni şifrenizi tekrar girin',
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre tekrarı boş olamaz';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                      ),

                      // Güvenlik uyarısı
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Güçlü bir şifre seçin ve kimseyle paylaşmayın',
                                style: TextStyle(
                                  color: Colors.amber[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),

                      // Butonlar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('İptal'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.isAdmin
                                    ? Colors.orange[600]
                                    : Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      'Şifreyi Değiştir',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
