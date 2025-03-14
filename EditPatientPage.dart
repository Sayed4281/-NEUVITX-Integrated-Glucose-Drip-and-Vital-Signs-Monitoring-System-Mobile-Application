import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPatientPage extends StatefulWidget {
  final String patientId;

  EditPatientPage({required this.patientId});

  @override
  _EditPatientPageState createState() => _EditPatientPageState();
}

class _EditPatientPageState extends State<EditPatientPage> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _patientData = {};

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).get();
    if (snapshot.exists) {
      setState(() {
        _patientData = Map<String, dynamic>.from(snapshot.data() as Map<String, dynamic>);
      });
    }
  }

  Future<void> _updatePatient() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).update(_patientData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit Patient Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade900,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _updatePatient,
            tooltip: 'Save Changes',
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
        child: _patientData.isEmpty
            ? Center(
          child: CircularProgressIndicator(
            color: Colors.blue.shade900,
          ),
        )
            : SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildTextField('Name', 'name', required: true),
                    _buildTextField('Email', 'email',
                        keyboardType: TextInputType.emailAddress, required: true),
                    _buildTextField('Phone', 'phone',
                        keyboardType: TextInputType.phone, required: true),
                    _buildTextField('Secondary Phone', 'secondary phone',
                        keyboardType: TextInputType.phone),
                    _buildTextField('Address', 'address', maxLines: 2),
                    _buildTextField('Age', 'age',
                        keyboardType: TextInputType.number, required: true),
                    _buildTextField('Place', 'place'),
                    _buildTextField('Disease', 'disease'),
                    _buildTextField('Doctor', 'doctor'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: _patientData[key]?.toString() ?? '',
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blue.shade900),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade900, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: required
            ? (value) => value!.isEmpty ? 'Please enter $label' : null
            : null,
        onSaved: (value) => _patientData[key] = value,
      ),
    );
  }
}