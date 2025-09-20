import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyScoresScreen extends StatefulWidget {
  final String parentUsername; // Veli kullanıcı adı

  WeeklyScoresScreen({required this.parentUsername});

  @override
  _WeeklyScoresScreenState createState() => _WeeklyScoresScreenState();
}

class _WeeklyScoresScreenState extends State<WeeklyScoresScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> weeklyScores = {};

  @override
  void initState() {
    super.initState();
    _fetchWeeklyScores();
  }

  void _fetchWeeklyScores() async {
    var studentDocs = await _db
        .collection('users')
        .doc(widget.parentUsername)
        .collection('students')
        .get();

    Map<String, Map<String, dynamic>> tempScores = {};
    for (var student in studentDocs.docs) {
      var scoresSnapshot = await student.reference
          .collection('weekly_scores')
          .get();
      tempScores[student['name']] = {
        for (var doc in scoresSnapshot.docs) doc.id: doc.data(),
      };
    }

    setState(() {
      weeklyScores = tempScores;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Haftalık Soru Bilgileri')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: weeklyScores.entries.map((entry) {
          String studentName = entry.key;
          Map<String, dynamic> scores = entry.value;
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ...scores.entries.map((scoreEntry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${scoreEntry.key}: ${scoreEntry.value.toString()}',
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
