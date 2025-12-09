
import 'package:daaymn/profile_creation/profile_data_model.dart';
import 'package:flutter/material.dart';

class GetAttentionPage extends StatefulWidget {
  final VoidCallback onNext;
  final ProfileData profileData;

  const GetAttentionPage({super.key, required this.onNext, required this.profileData});

  @override
  State<GetAttentionPage> createState() => _GetAttentionPageState();
}

class _GetAttentionPageState extends State<GetAttentionPage> {
  late final TextEditingController _workController;
  late final TextEditingController _religionController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _workController = TextEditingController(text: widget.profileData.work);
    _religionController = TextEditingController(text: widget.profileData.religion);
    _heightController = TextEditingController(text: widget.profileData.heightCm?.toString());
    _weightController = TextEditingController(text: widget.profileData.weightKg?.toString());
  }

  void _saveDataAndProceed() {
    widget.profileData.work = _workController.text.trim();
    widget.profileData.religion = _religionController.text.trim();
    widget.profileData.heightCm = double.tryParse(_heightController.text);
    widget.profileData.weightKg = double.tryParse(_weightController.text);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Get Attention (Optional)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildOptionalTextField(controller: _workController, labelText: 'Work', value: widget.profileData.showWork, onChanged: (newValue) => setState(() => widget.profileData.showWork = newValue!)),
                    const SizedBox(height: 16),
                    _buildOptionalTextField(controller: _religionController, labelText: 'Religion', value: widget.profileData.showReligion, onChanged: (newValue) => setState(() => widget.profileData.showReligion = newValue!)),
                    const SizedBox(height: 16),
                    _buildOptionalTextField(controller: _heightController, labelText: 'Height (cm)', value: widget.profileData.showHeight, onChanged: (newValue) => setState(() => widget.profileData.showHeight = newValue!)),
                    const SizedBox(height: 16),
                    _buildOptionalTextField(controller: _weightController, labelText: 'Weight (kg)', value: widget.profileData.showWeight, onChanged: (newValue) => setState(() => widget.profileData.showWeight = newValue!)),
                    const SizedBox(height: 16),
                    _buildOptionalDropdownField<String>(
                      initialValue: widget.profileData.dominantHand,
                      labelText: 'Dominant Hand',
                      items: ['Right', 'Left', 'Ambidextrous'],
                      onChanged: (newValue) => setState(() => widget.profileData.dominantHand = newValue),
                      showValue: widget.profileData.showDominantHand,
                      onShowChanged: (newValue) => setState(() => widget.profileData.showDominantHand = newValue!),
                    ),
                    const SizedBox(height: 16),
                    _buildOptionalDropdownField<String>(
                      initialValue: widget.profileData.devicePreference,
                      labelText: 'Device Preference',
                      items: ['Apple', 'Android', 'Other'],
                      onChanged: (newValue) => setState(() => widget.profileData.devicePreference = newValue),
                      showValue: widget.profileData.showDevicePreference,
                      onShowChanged: (newValue) => setState(() => widget.profileData.showDevicePreference = newValue!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onNext,
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveDataAndProceed,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalTextField({
    required TextEditingController controller,
    required String labelText,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(controller: controller, decoration: InputDecoration(labelText: '$labelText (Optional)', border: const OutlineInputBorder())),
        CheckboxListTile(
          title: const Text('Display on profile'),
          value: value,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildOptionalDropdownField<T>({
    required T? initialValue,
    required String labelText,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool showValue,
    required ValueChanged<bool?> onShowChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          initialValue: initialValue,
          decoration: InputDecoration(labelText: '$labelText (Optional)', border: const OutlineInputBorder()),
          items: items.map((T item) => DropdownMenuItem<T>(value: item, child: Text(item.toString()))).toList(),
          onChanged: onChanged,
        ),
        CheckboxListTile(
          title: const Text('Display on profile'),
          value: showValue,
          onChanged: onShowChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
