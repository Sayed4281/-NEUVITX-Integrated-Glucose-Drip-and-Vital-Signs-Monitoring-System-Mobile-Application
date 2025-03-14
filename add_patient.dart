import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddPatientPage extends StatefulWidget {
  @override
  _AddPatientPageState createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController secondaryPhoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController placeController = TextEditingController();
  final TextEditingController diseaseController = TextEditingController();
  final TextEditingController doctorController = TextEditingController();

  // Function to generate a custom unique ID starting with NVX
  String _generatePatientID() {
    String timestamp = DateFormat('MMddHHmmss').format(DateTime.now()); // Example: 0623102530
    return "NVX$timestamp";
  }

  // Function to add patient details to Firestore
  Future<void> _addPatient() async {
    if (_formKey.currentState!.validate()) {
      String patientId = _generatePatientID(); // Generate short ID with NVX prefix

      try {
        await FirebaseFirestore.instance.collection('patients').doc(patientId).set({
          'patientId': patientId,
          'name': nameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'secondaryPhone': secondaryPhoneController.text.isNotEmpty ? secondaryPhoneController.text : null,
          'address': addressController.text,
          'age': int.parse(ageController.text),
          'place': placeController.text,
          'disease': diseaseController.text,
          'doctor': 'Dr. ${doctorController.text}',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Patient added successfully! ID: $patientId")),
        );

        // Clear fields
        _clearFields();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding patient: $e")),
        );
      }
    }
  }

  // Function to clear form fields
  void _clearFields() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    secondaryPhoneController.clear();
    addressController.clear();
    ageController.clear();
    placeController.clear();
    diseaseController.clear();
    doctorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Patient", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      "Patient Details",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    SizedBox(height: 10),

                    _buildTextField(nameController, "Name", Icons.person),
                    _buildTextField(emailController, "Email", Icons.email),
                    _buildTextField(phoneController, "Phone", Icons.phone_android, keyboardType: TextInputType.phone),
                    _buildTextField(secondaryPhoneController, "Secondary Phone", Icons.phone, keyboardType: TextInputType.phone, isOptional: true),
                    _buildTextField(addressController, "Address", Icons.location_on),
                    _buildTextField(ageController, "Age", Icons.calendar_today, keyboardType: TextInputType.number),
                    _buildTextField(placeController, "Place", Icons.map),
                    _buildTextField(diseaseController, "Disease", Icons.local_hospital),
                    _buildTextField(doctorController, "Doctor", Icons.medical_services),

                    SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _addPatient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text("Add Patient", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Function to create a styled text field with an icon
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        bool isOptional = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return "Enter $label";
          }
          return null;
        },
      ),
    );
  }
}
