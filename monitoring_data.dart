import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    home: MonitoringPage(),
  ));
}

class MonitoringPage extends StatefulWidget {
  final Function(List<String>)? onVitalAlerts;

  MonitoringPage({this.onVitalAlerts});

  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final FlutterTts _flutterTts = FlutterTts();
  List<String> activeAlerts = [];
  Map<String, int> _ttsCount = {};
  Map<String, Timer?> _ttsTimers = {};
  StreamSubscription<DatabaseEvent>? _vitalSubscription;
  StreamSubscription<DatabaseEvent>? _glucoseSubscription;
  int? latestBpm;
  int? latestSpo2;
  double? latestGlucose;
  String patientName = 'Unknown';

  Map<String, int> _abnormalCount = {'highBpm': 0, 'lowBpm': 0, 'highSpo2': 0, 'lowSpo2': 0};
  static const Duration TTS_INTERVAL = Duration(seconds: 3);
  static const int MAX_TTS_REPEATS = 3;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _listenToDataStreams();
    _fetchPatientName();
    // Removed manual test data for real-time monitoring
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _vitalSubscription?.cancel();
    _glucoseSubscription?.cancel();
    _ttsTimers.forEach((_, timer) => timer?.cancel());
    super.dispose();
  }

  void _setupTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak("Monitoring system initialized");
      print("MonitoringPage: TTS initialized successfully");
    } catch (e) {
      print("MonitoringPage: Error setting up TTS: $e");
    }
  }

  void _fetchPatientName() async {
    try {
      final activeMonitoring = await FirebaseFirestore.instance
          .collection('patients')
          .where('isMonitoringEnabled', isEqualTo: true)
          .limit(1)
          .get();

      if (activeMonitoring.docs.isNotEmpty) {
        var patientData = activeMonitoring.docs.first.data() as Map<String, dynamic>;
        setState(() {
          patientName = patientData['name'] ?? 'Unknown';
          print("MonitoringPage: Patient Name Set: $patientName");
        });
      }
    } catch (e) {
      print("MonitoringPage: Error fetching patient name: $e");
    }
  }

  void _listenToDataStreams() {
    DatabaseReference vitalRef = FirebaseDatabase.instance.ref("vitals");
    DatabaseReference glucoseRef = FirebaseDatabase.instance.ref("glucose");

    _vitalSubscription = vitalRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        var vitalData = event.snapshot.value;
        setState(() {
          if (vitalData is Map<dynamic, dynamic>) {
            latestBpm = num.tryParse(vitalData['bpm']?.toString() ?? '0')?.round() ?? 0;
            latestSpo2 = num.tryParse(vitalData['spo2']?.toString() ?? '0')?.round() ?? 0;
          } else {
            latestBpm = num.tryParse(vitalData.toString())?.round() ?? 0;
            latestSpo2 = 0;
          }
          _checkVitalsAndTriggerImmediateAlerts();
        });
      }
    }, onError: (error) {
      print("MonitoringPage: Vital Stream Error: $error");
    });

    _glucoseSubscription = glucoseRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        var rawValue = event.snapshot.value;
        setState(() {
          if (rawValue is num) {
            latestGlucose = rawValue.toDouble();
          } else if (rawValue is Map) {
            latestGlucose = (rawValue['glucose_level'] as num?)?.toDouble() ?? 0;
          } else {
            latestGlucose = double.tryParse(rawValue.toString()) ?? 0;
          }
          _checkAndTriggerGlucoseAlerts();
        });
      }
    }, onError: (error) {
      print("MonitoringPage: Glucose Stream Error: $error");
    });
  }

  Future<void> _triggerAlert(String problem) async {
    String message = "Alert: $patientName has $problem";
    if (!activeAlerts.contains(message)) {
      setState(() {
        activeAlerts.add(message);
        _ttsCount[message] = 0;
      });

      await _flutterTts.stop();

      _ttsTimers[message] = Timer.periodic(TTS_INTERVAL, (timer) async {
        if (_ttsCount[message]! < MAX_TTS_REPEATS) {
          try {
            await _flutterTts.speak(message);
            _ttsCount[message] = _ttsCount[message]! + 1;
          } catch (e) {
            print("MonitoringPage: Error speaking TTS: $e");
          }
        } else {
          timer.cancel();
          _ttsTimers[message] = null;
        }
      });

      if (widget.onVitalAlerts != null) {
        widget.onVitalAlerts!(activeAlerts);
      }
    }
  }

  void _checkVitalsAndTriggerImmediateAlerts() {
    // Immediate alert checking without threshold delays
    if (latestBpm != null) {
      if (latestBpm! > 99) {
        _triggerAlert("high BPM");
      } else if (latestBpm! < 50) {
        _triggerAlert("low BPM");
      }
    }

    if (latestSpo2 != null) {
      if (latestSpo2! > 101) {
        _triggerAlert("high SpO2");
      } else if (latestSpo2! < 94) {
        _triggerAlert("low SpO2");
      }
    }

    _checkAndRemoveNormalizedAlerts();
  }

  void _checkAndTriggerGlucoseAlerts() {
    if (latestGlucose != null) {
      if (latestGlucose! < 50) {
        _triggerAlert("glucose level below 50 mg/dL");
      }
    }
    _checkAndRemoveNormalizedAlerts();
  }

  void _checkAndRemoveNormalizedAlerts() {
    List<String> alertsToRemove = [];
    for (String alert in activeAlerts) {
      if (alert.contains("high BPM") && latestBpm != null && latestBpm! <= 99) {
        alertsToRemove.add(alert);
      } else if (alert.contains("low BPM") && latestBpm != null && latestBpm! >= 50) {
        alertsToRemove.add(alert);
      } else if (alert.contains("high SpO2") && latestSpo2 != null && latestSpo2! <= 101) {
        alertsToRemove.add(alert);
      } else if (alert.contains("low SpO2") && latestSpo2 != null && latestSpo2! >= 94) {
        alertsToRemove.add(alert);
      } else if (alert.contains("glucose level below 50 mg/dL") && latestGlucose != null && latestGlucose! >= 50) {
        alertsToRemove.add(alert);
      }
    }

    if (alertsToRemove.isNotEmpty) {
      setState(() {
        for (String alert in alertsToRemove) {
          activeAlerts.remove(alert);
          _ttsTimers[alert]?.cancel();
          _ttsTimers[alert] = null;
          _ttsCount.remove(alert);
        }
      });
      _flutterTts.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Monitoring Dashboard"),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Monitoring Dashboard",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patients')
                    .where('isMonitoringEnabled', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Colors.blue.shade900));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No active monitoring patients found'));
                  }

                  var patient = snapshot.data!.docs.first;
                  var patientData = patient.data() as Map<String, dynamic>;
                  patientName = patientData['name'] ?? 'Unknown';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('patients')
                        .doc(patient.id)
                        .collection('monitoringLogs')
                        .orderBy('startTime', descending: true)
                        .snapshots(),
                    builder: (context, logSnapshot) {
                      if (!logSnapshot.hasData || logSnapshot.data!.docs.isEmpty) {
                        return Center(child: Text('Monitoring has not started yet'));
                      }

                      var logData = logSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      var startTime = logData['startTime'].toDate();
                      var stopTime = logData['stopTime']?.toDate();

                      String sessionId = "${startTime.toIso8601String()}-${DateTime.now().millisecondsSinceEpoch}";
                      _createMonitoringSession(patient.id, logData, sessionId);
                      _listenForMonitoringEnd(patient.id, sessionId, startTime);

                      return ListView(
                        children: [
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Patient: $patientName",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text("ID: ${patient.id}", style: TextStyle(fontSize: 16)),
                                  SizedBox(height: 8),
                                  Text("Start Time: $startTime"),
                                  if (stopTime != null) Text("Stop Time: $stopTime"),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _iconButton(
                                context,
                                Icons.monitor_heart,
                                Colors.green,
                                "Vitals",
                                VitalPage(
                                  patientId: patient.id,
                                  sessionId: sessionId,
                                  patientName: patientName,
                                ),
                                startTime,
                                stopTime,
                              ),
                              _iconButton(
                                context,
                                Icons.local_drink,
                                Colors.orange,
                                "Glucose",
                                GlucosePage(patientName: patientName),
                                startTime,
                                stopTime,
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (activeAlerts.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Active Alerts:",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...activeAlerts.map((alert) => Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alert,
                                          style: TextStyle(fontSize: 16, color: Colors.red),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.red),
                                        onPressed: () async {
                                          await _flutterTts.stop();
                                          _ttsTimers[alert]?.cancel();
                                          _ttsTimers[alert] = null;
                                          setState(() {
                                            activeAlerts.remove(alert);
                                            _ttsCount.remove(alert);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text("Latest BPM: ${latestBpm ?? 'N/A'}"),
                              Text("Latest SpO2: ${latestSpo2 ?? 'N/A'}%"),
                              Text("Glucose: ${latestGlucose?.toStringAsFixed(1) ?? 'N/A'} mg/dL"),
                            ],
                          ),
                        ],
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

  void _createMonitoringSession(String patientId, Map<String, dynamic> logData, String sessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('data')
          .doc(sessionId)
          .set({
        'startTime': logData['startTime'],
        'stopTime': logData['stopTime'],
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print("MonitoringPage: Error creating monitoring session: $e");
    }
  }

  void _listenForMonitoringEnd(String patientId, String sessionId, DateTime startTime) async {
    FirebaseFirestore.instance.collection('patients').doc(patientId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      var patientData = snapshot.data() as Map<String, dynamic>;
      bool isMonitoringEnabled = patientData['isMonitoringEnabled'] ?? false;

      if (!isMonitoringEnabled) {
        DateTime stopTime = DateTime.now();
        int duration = stopTime.difference(startTime).inSeconds;

        try {
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(patientId)
              .collection('data')
              .doc(sessionId)
              .update({
            'stopTime': Timestamp.fromDate(stopTime),
            'duration': duration,
          });
        } catch (e) {
          print("MonitoringPage: Error updating monitoring session: $e");
        }
      }
    });
  }

  Widget _iconButton(BuildContext context, IconData icon, Color color, String label, Widget page,
      DateTime startTime, DateTime? stopTime) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
              settings: RouteSettings(arguments: {'startTime': startTime, 'stopTime': stopTime}),
            ),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: color,
            child: Icon(icon, size: 50, color: Colors.white),
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class VitalPage extends StatefulWidget {
  final String patientId;
  final String sessionId;
  final String patientName;

  VitalPage({
    required this.patientId,
    required this.sessionId,
    required this.patientName,
  });

  @override
  _VitalPageState createState() => _VitalPageState();
}

class _VitalPageState extends State<VitalPage> {
  List<Map<String, dynamic>> _filterAndStoreVitals(
      Map<dynamic, dynamic> vitalMap, DateTime startTime, DateTime? stopTime) {
    var filteredData = vitalMap.entries.where((entry) {
      try {
        var data = Map<String, dynamic>.from(entry.value);
        String date = data['date'];
        String time = data['timestamp'];
        DateTime timestamp = DateFormat("yyyy-MM-dd hh:mm a").parse("$date $time");

        bool isAfterStart = timestamp.isAfter(startTime);
        bool isBeforeStop = stopTime == null || timestamp.isBefore(stopTime);

        if (isAfterStart && isBeforeStop) {
          _storeVitalDataInFirestore(widget.patientId, widget.sessionId, data, timestamp);
          return true;
        }
        return false;
      } catch (e) {
        print("VitalPage: Error parsing vital data: ${entry.value}, Error: $e");
        return false;
      }
    }).map((entry) => Map<String, dynamic>.from(entry.value)).toList();

    filteredData.sort((a, b) {
      DateTime aTime = DateFormat("yyyy-MM-dd hh:mm a").parse("${a['date']} ${a['timestamp']}");
      DateTime bTime = DateFormat("yyyy-MM-dd hh:mm a").parse("${b['date']} ${b['timestamp']}");
      return aTime.compareTo(bTime);
    });

    return filteredData;
  }

  void _storeVitalDataInFirestore(
      String patientId, String sessionId, Map<String, dynamic> data, DateTime timestamp) async {
    String vitalId = "${timestamp.toIso8601String()}-${DateTime.now().millisecondsSinceEpoch}";
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('data')
          .doc(sessionId)
          .collection('vitals')
          .doc(vitalId)
          .set({
        'bpm': data['bpm'].toString(),
        'spo2': data['spo2'].toString(),
        'date': data['date'],
        'timestamp': data['timestamp'],
        'recordedAt': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      print("VitalPage: Error storing vital data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final DateTime startTime = args['startTime'];
    final DateTime? stopTime = args['stopTime'];

    DatabaseReference vitalRef = FirebaseDatabase.instance.ref("vitals");

    return Scaffold(
      appBar: AppBar(
        title: Text("Vital Monitoring"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: vitalRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text("No vital data available."));
          }

          var vitalData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          var filteredData = _filterAndStoreVitals(vitalData, startTime, stopTime);

          if (filteredData.isEmpty) {
            return Center(child: Text("No recent vital data within session."));
          }

          var graphData = filteredData.length > 4 ? filteredData.sublist(filteredData.length - 4) : filteredData;

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: graphData.asMap().entries.map((entry) {
                        int index = entry.key;
                        var data = entry.value;
                        int bpm = num.parse(data['bpm'].toString()).round();
                        int spo2 = num.parse(data['spo2'].toString()).round();

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: bpm.toDouble(),
                              color: Colors.green,
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: spo2.toDouble(),
                              color: Colors.blue,
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index < 0 || index >= graphData.length) return Text('');
                              var data = graphData[index];
                              DateTime time = DateFormat("yyyy-MM-dd hh:mm a")
                                  .parse("${data['date']} ${data['timestamp']}");
                              return Text(
                                DateFormat('HH:mm').format(time),
                                style: TextStyle(fontSize: 12),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                            },
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      gridData: FlGridData(drawHorizontalLine: true, drawVerticalLine: true),
                      minY: 0,
                      maxY: 150,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [Container(width: 16, height: 16, color: Colors.green), SizedBox(width: 8), Text("BPM")]),
                    SizedBox(width: 20),
                    Row(children: [Container(width: 16, height: 16, color: Colors.blue), SizedBox(width: 8), Text("SpO2")]),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      var data = filteredData[index];
                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "BPM: ${data['bpm']}, SpO2: ${data['spo2']}%, Date: ${data['date']}, Time: ${data['timestamp']}",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GlucosePage extends StatefulWidget {
  final String patientName;

  GlucosePage({required this.patientName});

  @override
  _GlucosePageState createState() => _GlucosePageState();
}

class _GlucosePageState extends State<GlucosePage> {
  @override
  Widget build(BuildContext context) {
    DatabaseReference glucoseRef = FirebaseDatabase.instance.ref("glucose");

    return Scaffold(
      appBar: AppBar(
        title: Text("Glucose Monitoring"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: glucoseRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text("Waiting for glucose data..."));
          }

          var rawValue = snapshot.data!.snapshot.value;
          double glucoseValue;

          try {
            if (rawValue is num) {
              glucoseValue = rawValue.toDouble();
            } else if (rawValue is Map) {
              glucoseValue = (rawValue['glucose_level'] as num?)?.toDouble() ?? double.parse(rawValue['glucose_level'].toString());
            } else {
              glucoseValue = double.parse(rawValue.toString());
            }
          } catch (e) {
            print("GlucosePage: Error parsing glucose value: $e");
            return Center(child: Text("Error parsing glucose data"));
          }

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: 400,
                      width: 200,
                      child: CustomPaint(
                        painter: BottlePainter(glucoseValue: glucoseValue),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Text(
                              "$glucoseValue mg/dL",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 4.0, color: Colors.black, offset: Offset(2.0, 2.0)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BottlePainter extends CustomPainter {
  final double glucoseValue;

  BottlePainter({required this.glucoseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    double bottleWidth = size.width * 0.6;
    double bottleHeight = size.height * 0.8;
    double neckHeight = size.height * 0.15;
    double capHeight = size.height * 0.1;
    double capWidth = bottleWidth * 0.5;

    Path bottlePath = Path();
    bottlePath.moveTo(size.width / 2 - bottleWidth / 2, neckHeight);
    bottlePath.quadraticBezierTo(size.width / 2 - bottleWidth * 0.7, neckHeight + bottleHeight * 0.3, size.width / 2 - bottleWidth / 2, neckHeight + bottleHeight);
    bottlePath.lineTo(size.width / 2 + bottleWidth / 2, neckHeight + bottleHeight);
    bottlePath.quadraticBezierTo(size.width / 2 + bottleWidth * 0.7, neckHeight + bottleHeight * 0.3, size.width / 2 + bottleWidth / 2, neckHeight);
    bottlePath.close();

    paint.color = Colors.blue.shade900;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4.0;
    canvas.drawPath(bottlePath, paint);

    double maxGlucose = 300.0;
    double liquidHeight = (glucoseValue.clamp(0, maxGlucose) / maxGlucose) * bottleHeight;
    double liquidTop = neckHeight + bottleHeight - liquidHeight;

    Path liquidPath = Path();
    liquidPath.moveTo(size.width / 2 - bottleWidth / 2, liquidTop);
    liquidPath.quadraticBezierTo(size.width / 2 - bottleWidth * 0.7, liquidTop + liquidHeight * 0.3, size.width / 2 - bottleWidth / 2, neckHeight + bottleHeight);
    liquidPath.lineTo(size.width / 2 + bottleWidth / 2, neckHeight + bottleHeight);
    liquidPath.quadraticBezierTo(size.width / 2 + bottleWidth * 0.7, liquidTop + liquidHeight * 0.3, size.width / 2 + bottleWidth / 2, liquidTop);
    liquidPath.close();

    paint.color = Colors.lightBlue.withOpacity(0.7);
    paint.style = PaintingStyle.fill;
    canvas.drawPath(liquidPath, paint);

    paint.color = Colors.grey.shade700;
    paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - capWidth / 2, 0, capWidth, capHeight), paint);

    paint.color = Colors.blue.shade900;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width / 2 - bottleWidth / 2, neckHeight), Offset(size.width / 2 - capWidth / 2, capHeight), paint);
    canvas.drawLine(Offset(size.width / 2 + bottleWidth / 2, neckHeight), Offset(size.width / 2 + capWidth / 2, capHeight), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}