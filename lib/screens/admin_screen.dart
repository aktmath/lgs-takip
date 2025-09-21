import 'package:flutter/material.dart';
import 'admin_manage_parents_screen.dart';
import 'admin_weekly_questions_screen.dart';
import 'admin_books_screen.dart';
import 'admin_exam_screen.dart';
import 'admin_subject_exam_screen.dart'; // YENİ EKLENEN
import 'admin_attendance_screen.dart';
import 'admin_announcement_screen.dart';
import 'admin_student_portfolio_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class AdminScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LGS Deneme Takip - Ogretmen Paneli'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            icon: Icon(Icons.logout),
            tooltip: 'Cikis Yap',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[800]!, Colors.blue[600]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hos Geldiniz',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'LGS Deneme Takip Sistemi',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                SizedBox(height: 30),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildMenuTile(
                        context,
                        'Veli Yonetimi',
                        'Veli ve ogrenci hesaplari',
                        Icons.people,
                        Colors.green,
                        AdminManageParentsScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Genel Denemeler',
                        'LGS deneme sinavi girisi',
                        Icons.quiz,
                        Colors.purple,
                        AdminExamScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Ders Denemeleri', // YENİ EKLENEN
                        'Ders bazında deneme takibi',
                        Icons.school,
                        Colors.indigo,
                        AdminSubjectExamScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Haftalik Sorular',
                        'Cozulen soru sayilari',
                        Icons.assignment,
                        Colors.orange,
                        AdminWeeklyQuestionsScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Ogrenci Kitaplari',
                        'Okunan kitap takibi',
                        Icons.book,
                        Colors.teal,
                        AdminBooksScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Devam Durumu',
                        'Devamsizlik bildirimleri',
                        Icons.person_off,
                        Colors.red,
                        AdminAttendanceScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Duyurular',
                        'Veli duyuru yonetimi',
                        Icons.campaign,
                        Colors.pink,
                        AdminAnnouncementScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Ogrenci Portfolyolari',
                        'Gecmis ve analiz',
                        Icons.folder_shared,
                        Colors.cyan,
                        AdminStudentPortfolioScreen(),
                      ),
                      _buildMenuTile(
                        context,
                        'Şifre Değiştir',
                        'Güvenlik ayarları',
                        Icons.security,
                        Colors.deepOrange,
                        ChangePasswordScreen(username: 'admin', isAdmin: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
