
import 'package:daaymn/profile_creation/profile_data_model.dart';
import 'package:flutter/material.dart';

class EssentialsPage extends StatefulWidget {
  final VoidCallback onNext;
  final ProfileData profileData;

  const EssentialsPage({super.key, required this.onNext, required this.profileData});

  @override
  State<EssentialsPage> createState() => _EssentialsPageState();
}

class _EssentialsPageState extends State<EssentialsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profileData.name);
    _ageController = TextEditingController(text: widget.profileData.age?.toString());
    _cityController = TextEditingController(text: widget.profileData.city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('The Essentials', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()), validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your name' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _ageController, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (value) { if (value == null || value.isEmpty) return 'Please enter your age'; if (int.tryParse(value) == null || int.parse(value) < 18) return 'You must be at least 18'; return null; }),
                      const SizedBox(height: 16),
                      TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()), validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your city' : null),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(initialValue: widget.profileData.gender, decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()), items: ['Male', 'Female', 'Other'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => widget.profileData.gender = newValue), validator: (value) => value == null ? 'Please select a gender' : null),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(initialValue: widget.profileData.pronouns, decoration: const InputDecoration(labelText: 'Pronouns', border: OutlineInputBorder()), items: ['he/him', 'she/her', 'they/them', 'Other'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => widget.profileData.pronouns = newValue), validator: (value) => value == null ? 'Please select your pronouns' : null),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(initialValue: widget.profileData.ethnicity, decoration: const InputDecoration(labelText: 'Ethnicity', border: OutlineInputBorder()), items: ['Asian', 'African', 'Hispanic or Latino', 'Caucasian', 'Native American', 'Pacific Islander', 'Middle Eastern', 'Other'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => widget.profileData.ethnicity = newValue), validator: (value) => value == null ? 'Please select an ethnicity' : null),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.profileData.name = _nameController.text.trim();
                    widget.profileData.age = int.tryParse(_ageController.text);
                    widget.profileData.city = _cityController.text.trim();
                    widget.onNext();
                  }
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
