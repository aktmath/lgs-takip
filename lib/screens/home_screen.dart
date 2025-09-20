import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'parent_home_screen.dart';
import 'admin_screen.dart';
import '../services/firestore_services.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isAdminUser = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  void _checkAdmin() async {
    try {
      // FirestoreServices içinde isAdmin fonksiyonunu kullanabiliriz, yoksa basit bir kontrol
      // Örnek: username "admin" ise admin kabul et
      isAdminUser = widget.username.toLowerCase() == 'admin';
    } catch (e) {
      print('Admin check error: $e');
      isAdminUser = false;
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return isAdminUser
        ? AdminScreen()
        : ParentHomeScreen(username: widget.username);
  }
}
