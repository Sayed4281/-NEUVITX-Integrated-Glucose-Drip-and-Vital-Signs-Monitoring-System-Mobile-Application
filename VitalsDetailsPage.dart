import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For parsing and formatting dates

class VitalsDetailsPage extends StatelessWidget {
  final String patientId; // Passed from PatientDetailPage, unused in query
  final DateTime startTime; // Changed from Timestamp to DateTime
  final DateTime stopTime;

  VitalsDetailsPage({
    required this.patientId,
    required this.startTime,
    required this.stopTime,
  });

  // Reference to the Realtime Database, directly under 'vitals'
  final DatabaseReference _vitalsRef = FirebaseDatabase.instance.ref('vitals');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Vitals Details"),
        backgroundColor: Colors.blue.shade900,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _vitalsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 18, color: Colors.red)));
          }

          // Default content: show start and stop times in 12-hour format
          Widget content = Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Vitals Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                _buildVitalItem("Monitor Start Time", _formatTimestamp(startTime)),
                _buildVitalItem("Monitor Stop Time", _formatTimestamp(stopTime)),
              ],
            ),
          );

          // Process Realtime Database data
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value;
            Map<String, dynamic> vitalsMap = {};

            if (data is Map) {
              vitalsMap = Map<String, dynamic>.from(data);
            }

            // Filter vitals based on combined date and timestamp
            final filteredVitals = vitalsMap.entries.where((entry) {
              try {
                final vitalData = entry.value as Map<dynamic, dynamic>;
                final String dateStr = vitalData['date'] as String; // "2025-03-09"
                final String timeStr = vitalData['timestamp'] as String; // "12:42 AM"
                final String fullTimestamp = "$timeStr $dateStr"; // "12:42 AM 2025-03-09"
                final DateTime vitalDateTime = DateFormat('hh:mm a yyyy-MM-dd').parse(fullTimestamp);
                return vitalDateTime.isAfter(startTime) && vitalDateTime.isBefore(stopTime);
              } catch (e) {
                print('Error parsing timestamp for entry ${entry.key}: $e');
                return false; // Skip invalid entries
              }
            }).toList();

            if (filteredVitals.isNotEmpty) {
              content = Padding(
                padding: EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Vitals Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      _buildVitalItem("Monitor Start Time", _formatTimestamp(startTime)),
                      _buildVitalItem("Monitor Stop Time", _formatTimestamp(stopTime)),
                      SizedBox(height: 20),
                      Text("Vital Records", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      // Display all filtered vitals in a list
                      ...filteredVitals.map((entry) {
                        final vitalData = entry.value as Map<dynamic, dynamic>;
                        final String timeStr = vitalData['timestamp'] as String;
                        final String dateStr = vitalData['date'] as String;
                        final String fullTimestamp = "$timeStr $dateStr";
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Time: $fullTimestamp", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                if (vitalData['bpm'] != null)
                                  _buildVitalItem("BPM", "${vitalData['bpm']} bpm"),
                                if (vitalData['spo2'] != null)
                                  _buildVitalItem("SPO2", "${vitalData['spo2']}%"),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }
          }

          return content;
        },
      ),
    );
  }

  Widget _buildVitalItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text("$label: ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return DateFormat('hh:mm a yyyy-MM-dd').format(dateTime); // 12-hour format like "12:42 AM 2025-03-09"
  }
}