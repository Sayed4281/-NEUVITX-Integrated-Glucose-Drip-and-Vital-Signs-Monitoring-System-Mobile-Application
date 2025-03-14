import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_patient.dart';
import 'main.dart';
import 'patient_detail.dart';
import 'monitoring_data.dart';
import 'package:firebase_database/firebase_database.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = "";
  TextEditingController passwordController = TextEditingController();
  String password = 'nvx@786';
  Map<String, dynamic>? _currentMonitoringDetails;
  Map<String, dynamic>? _currentPatientDetails;

  @override
  void initState() {
    super.initState();
    _fetchCurrentMonitoringDetails();
    _listenToDataStreams(); // Kept for data streaming, but no alert logic
  }

  void _fetchCurrentMonitoringDetails() async {
    final activeMonitoring = await FirebaseFirestore.instance
        .collection('patients')
        .where('isMonitoringEnabled', isEqualTo: true)
        .get();

    if (activeMonitoring.docs.isNotEmpty) {
      final patientId = activeMonitoring.docs.first.id;
      final patientData = activeMonitoring.docs.first.data();
      final monitoringLogRef = FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('monitoringLogs')
          .orderBy('startTime', descending: true)
          .limit(1);

      final monitoringData = await monitoringLogRef.get();
      if (monitoringData.docs.isNotEmpty) {
        setState(() {
          _currentMonitoringDetails = monitoringData.docs.first.data();
          _currentPatientDetails = {
            'name': patientData['name'],
            'id': patientId,
          };
        });
      }
    } else {
      setState(() {
        _currentMonitoringDetails = null;
        _currentPatientDetails = null;
      });
    }
  }

  void _listenToDataStreams() {
    DatabaseReference vitalRef = FirebaseDatabase.instance.ref("vitals");
    DatabaseReference glucoseRef = FirebaseDatabase.instance.ref("glucose");

    vitalRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        var vitalData = event.snapshot.value;
        if (vitalData is Map<dynamic, dynamic>) {
          // Data is still fetched, but no alerts are triggered
          num.tryParse(vitalData['bpm']?.toString() ?? '')?.round();
          num.tryParse(vitalData['spo2']?.toString() ?? '')?.round();
        }
      }
    });

    glucoseRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        var rawValue = event.snapshot.value;
        if (rawValue is num) {
          rawValue.toDouble();
        } else if (rawValue is Map) {
          (rawValue['glucose_level'] as num?)?.toDouble() ??
              double.tryParse(rawValue['glucose_level']?.toString() ?? '');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: Text('NeuVitX',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WelcomePage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPatientPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.monitor_heart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonitoringPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade900),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            SizedBox(height: 16),
            if (_currentMonitoringDetails != null && _currentPatientDetails != null)
              Card(
                elevation: 6,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Currently Monitoring',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Patient Name: ${_currentPatientDetails!['name']}',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        'Patient ID: ${_currentPatientDetails!['id']}',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Status: ${_currentMonitoringDetails!['status']}',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        'Start Time: ${_currentMonitoringDetails!['startTime'].toDate()}',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      if (_currentMonitoringDetails!['stopTime'] != null)
                        Text(
                          'Stop Time: ${_currentMonitoringDetails!['stopTime'].toDate()}',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      if (_currentMonitoringDetails!['duration'] != null)
                        Text(
                          'Duration: ${_currentMonitoringDetails!['duration']} seconds',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.monitor_heart),
              label: Text("View Monitoring Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MonitoringPage(),
                  ),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('patients').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final patients = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['name']?.toLowerCase() ?? '';
                    String id = doc.id.toLowerCase();
                    return name.contains(_searchQuery) || id.contains(_searchQuery);
                  }).toList();

                  if (patients.isEmpty) {
                    return Center(child: Text('No patients found'));
                  }

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      var patient = patients[index].data() as Map<String, dynamic>;
                      bool isMonitoringEnabled = patient['isMonitoringEnabled'] ?? false;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientDetailPage(patientId: patients[index].id),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 6,
                          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            title: Text(
                              patient['name'] ?? 'Unknown Name',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900),
                            ),
                            subtitle: Text(
                              'ID: ${patients[index].id}',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMonitoringEnabled ? Colors.red : Colors.green,
                              ),
                              onPressed: () async {
                                _showPasswordDialog(context, patients[index].id, isMonitoringEnabled);
                              },
                              child: Text(
                                isMonitoringEnabled ? 'Stop Monitoring' : 'Start Monitoring',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, String patientId, bool isMonitoringEnabled) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (passwordController.text == password) {
                  passwordController.clear();
                  Navigator.pop(context);
                  await _toggleMonitoring(patientId, isMonitoringEnabled);
                  _fetchCurrentMonitoringDetails();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Incorrect password'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('Confirm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleMonitoring(String patientId, bool isMonitoringEnabled) async {
    final patientRef = FirebaseFirestore.instance.collection('patients').doc(patientId);
    final monitoringLogsRef = patientRef.collection('monitoringLogs');

    if (isMonitoringEnabled) {
      final stopTime = DateTime.now();
      final lastMonitoringLog = await monitoringLogsRef
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (lastMonitoringLog.docs.isNotEmpty) {
        final lastLog = lastMonitoringLog.docs.first;
        final startTime = lastLog['startTime'].toDate();
        final duration = stopTime.difference(startTime);

        await monitoringLogsRef.doc(lastLog.id).update({
          'status': 'Stopped',
          'stopTime': stopTime,
          'duration': duration.inSeconds,
        });

        await patientRef.update({'isMonitoringEnabled': false});
      }
    } else {
      final startTime = DateTime.now();
      final activeMonitoring = await FirebaseFirestore.instance
          .collection('patients')
          .where('isMonitoringEnabled', isEqualTo: true)
          .get();
      if (activeMonitoring.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stop current monitoring first'), backgroundColor: Colors.red));
        return;
      }

      await monitoringLogsRef.add({
        'status': 'Started',
        'startTime': startTime,
        'stopTime': null,
        'duration': null,
      });

      await patientRef.update({'isMonitoringEnabled': true});
    }
  }
}