import 'package:flutter/material.dart';
import 'admin_manage_parents_screen.dart';
import 'admin_weekly_questions_screen.dart';
import 'admin_books_screen.dart';
import 'admin_exam_screen.dart';
import 'admin_exam_results_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_announcement_screen.dart';
import 'admin_notifications_screen.dart';

class AdminScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Paneli')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildTile(context, 'Velileri Yönet', AdminManageParentsScreen()),
            _buildTile(
              context,
              'Haftalık Sorular',
              AdminWeeklyQuestionsScreen(),
            ),
            _buildTile(context, 'Kitaplar', AdminBooksScreen()),
            _buildTile(context, 'Sınav Ekle', AdminExamScreen()),
            _buildTile(context, 'Sınav Sonuçları', AdminExamResultsScreen()),
            _buildTile(context, 'Devam Takibi', AdminAttendanceScreen()),
            _buildTile(context, 'Duyurular', AdminAnnouncementScreen()),
            _buildTile(context, 'Bildirimler', AdminNotificationsScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, String title, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
