
import 'package:daaymn/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DisplaySettingsPage extends StatelessWidget {
  final VoidCallback onDone;
  const DisplaySettingsPage({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Daaymn!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Pacifico', fontSize: 50, color: Colors.pinkAccent),
              ),
              const SizedBox(height: 8),
              Text(
                'First, let\'s get things looking just right.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Choose your theme", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _ThemeSelectionCard(
                                  label: 'Light',
                                  isSelected: !themeProvider.isDaaymnbow && themeProvider.themeMode == ThemeMode.light,
                                  onTap: () {
                                    themeProvider.setTheme(ThemeMode.light);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ThemeSelectionCard(
                                  label: 'Dark',
                                  isSelected: !themeProvider.isDaaymnbow && themeProvider.themeMode == ThemeMode.dark,
                                  onTap: () {
                                    themeProvider.setTheme(ThemeMode.dark);
                                  },
                                ),
                              ),
                            ],
                          ),
                          _ThemeSelectionCard(
                            label: 'Daaymnbow Sprinkle',
                            isSelected: themeProvider.isDaaymnbow,
                            onTap: () {
                              themeProvider.setDaaymnbow(true);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text("Choose your font", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _FontSelectionCard(
                            label: 'Default',
                            fontFamily: 'Pacifico',
                            isSelected: themeProvider.fontFamily == 'Pacifico',
                            onChanged: (val) => themeProvider.setFont(val!),
                          ),
                          _FontSelectionCard(
                            label: 'Modern',
                            fontFamily: 'Inter',
                            isSelected: themeProvider.fontFamily == 'Inter',
                            onChanged: (val) => themeProvider.setFont(val!),
                          ),
                          _FontSelectionCard(
                            label: 'Funky',
                            fontFamily: 'Bungee',
                            isSelected: themeProvider.fontFamily == 'Bungee',
                            onChanged: (val) => themeProvider.setFont(val!),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: onDone,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelectionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeSelectionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: isSelected ? 4 : 1,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(label, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}

class _FontSelectionCard extends StatelessWidget {
  final String label;
  final String fontFamily;
  final bool isSelected;
  final ValueChanged<String?> onChanged;

  const _FontSelectionCard({
    required this.label,
    required this.fontFamily,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(label, style: TextStyle(fontFamily: fontFamily, fontSize: 20)),
        leading: Radio<String>(
          value: fontFamily,
          groupValue: isSelected ? fontFamily : null,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        onTap: () {
          if (!isSelected) {
            onChanged(fontFamily);
          }
        },
      ),
    );
  }
}
