import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'VitalsDetailsPage.dart';
import 'EditPatientPage.dart';

class PatientDetailPage extends StatelessWidget {
  final String patientId;

  PatientDetailPage({required this.patientId});

  final List<String> allowedFields = [
    'name', 'email', 'phone', 'secondary phone', 'address', 'age', 'place', 'disease', 'doctor'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Patient Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade900,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () => _navigateToEditPage(context),
            tooltip: 'Edit Patient',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: () => _deletePatient(context),
            tooltip: 'Delete Patient',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('patients').doc(patientId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.blue.shade900));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Text(
                  'Patient not found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            var patient = snapshot.data!.data() as Map<String, dynamic>;

            return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _patientInfoCard(patient),
                  SizedBox(height: 20),
                  Text(
                    "Monitoring Logs",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(child: _buildMonitoringLogsList(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateToEditPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditPatientPage(patientId: patientId)),
    ).then((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PatientDetailPage(patientId: patientId)),
      );
    });
  }

  void _deletePatient(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this patient? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.blue.shade900)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await FirebaseFirestore.instance.collection('patients').doc(patientId).delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Patient deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete patient: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonitoringLogsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('monitoringLogs')
          .orderBy('startTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.blue.shade900));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 18, color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No monitoring logs found', style: TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }

        var logs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            var log = logs[index].data() as Map<String, dynamic>;
            return _buildLogCard(context, log);
          },
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, Map<String, dynamic> log) {
    String startTime = _formatTimestamp(log['startTime'], format: 'HH:mm');
    String stopTime = _formatTimestamp(log['stopTime'], format: 'HH:mm');

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          if (log['startTime'] != null && log['stopTime'] != null && log['startTime'] is Timestamp && log['stopTime'] is Timestamp) {
            DateTime startDateTime = (log['startTime'] as Timestamp).toDate();
            DateTime stopDateTime = (log['stopTime'] as Timestamp).toDate();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VitalsDetailsPage(
                  patientId: patientId,
                  startTime: startDateTime,
                  stopTime: stopDateTime,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid or missing start/stop time in this log'), backgroundColor: Colors.red),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Start: $startTime", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  Text("Stop: $stopTime", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Duration: ${log['duration'] ?? 'N/A'} secs", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  Text("Status: ${log['status'] ?? 'Unknown'}", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp, {String format = 'yyyy-MM-dd HH:mm'}) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat(format).format(dateTime);
    } else if (timestamp is String) {
      return timestamp;
    }
    return "N/A";
  }

  Widget _patientInfoCard(Map<String, dynamic> patient) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Patient Information",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 16),
            ...patient.entries
                .where((entry) => allowedFields.contains(entry.key.toLowerCase()))
                .map((entry) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${entry.key.toUpperCase()}: ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value?.toString() ?? 'N/A',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ))
                .toList(),
          ],
        ),
      ),
    );
  }
}