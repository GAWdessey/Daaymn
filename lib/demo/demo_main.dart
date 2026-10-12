import 'package:daaymn/demo/demo_data.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:flutter/material.dart';

// Demo mode entrypoint: no Supabase, no Firebase, no login. Run with
// tool/run_demo.sh (see README). Shows the real ProfileCard on made-up people.
void main() => runApp(const DemoApp());

const _gradient = LinearGradient(
  colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daaymn (demo)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DemoHome(),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[DemoDiscover(), DemoMatches(), DemoScoreScreen(), DemoVibePicker()];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _gradient)),
        title: const Row(children: [
          Text('Daaymn ', style: TextStyle(fontFamily: 'Pacifico', color: Colors.white, fontSize: 24)),
          Text('| ', style: TextStyle(color: Colors.white, fontSize: 20)),
          Text('Demo profiles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Daaymn Score'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Vibe'),
        ],
      ),
    );
  }
}

// ---------- Discover (faces / browse, with a match pop-up) ----------

class DemoDiscover extends StatefulWidget {
  const DemoDiscover({super.key});

  @override
  State<DemoDiscover> createState() => _DemoDiscoverState();
}

class _DemoDiscoverState extends State<DemoDiscover> {
  final _controller = PageController();

  void _next({required bool liked}) {
    if (liked) _showMatch();
    final page = (_controller.page ?? 0).round();
    if (page < demoDiscover.length - 1) {
      _controller.animateToPage(page + 1, duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  void _showMatch() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("It's a Daaymn match!", textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 48, backgroundImage: NetworkImage(demoMatchPopup.imageUrl!)),
          const SizedBox(height: 12),
          Text('You and ${demoMatchPopup.name} liked each other.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep browsing')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => DemoChat(profile: demoMatchPopup)));
            },
            child: const Text('Say hi'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: demoDiscover.length,
      itemBuilder: (context, i) => Center(
        child: SingleChildScrollView(
          child: ProfileCard(
            profile: demoDiscover[i],
            onLike: () => _next(liked: true),
            onDislike: () => _next(liked: false),
          ),
        ),
      ),
    );
  }
}

// ---------- Matches list ----------

class DemoMatches extends StatelessWidget {
  const DemoMatches({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final p in demoMatches)
          ListTile(
            leading: CircleAvatar(radius: 28, backgroundImage: NetworkImage(p.imageUrl!)),
            title: Text('${p.name}, ${p.age}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.name == demoMatches.first.name ? 'Coffee after? I know a place.' : 'Say hi to your new match'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DemoChat(profile: p))),
          ),
      ],
    );
  }
}

// ---------- Chat ----------

class DemoChat extends StatelessWidget {
  final Profile profile;
  const DemoChat({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _gradient)),
        foregroundColor: Colors.white,
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundImage: NetworkImage(profile.imageUrl!)),
          const SizedBox(width: 10),
          Text(profile.name, style: const TextStyle(color: Colors.white)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in demoChat)
                Align(
                  alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: m.mine ? scheme.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(m.text, style: TextStyle(color: m.mine ? Colors.white : Colors.black87)),
                  ),
                ),
            ],
          ),
        ),
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              enabled: false,
              decoration: InputDecoration(hintText: 'Type a message', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------- Daaymn Score ----------

class DemoScoreScreen extends StatelessWidget {
  const DemoScoreScreen({super.key});

  Widget _pillar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: LinearProgressIndicator(value: value / 10, minHeight: 10, borderRadius: BorderRadius.circular(5))),
        const SizedBox(width: 12),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Text(demoScore.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
            const Text('#DaaymnScore', style: TextStyle(color: Colors.white, fontFamily: 'Pacifico', fontSize: 22)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('SCORE BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        _pillar('Popularity', demoPopularity),
        _pillar('Engagement', demoEngagement),
        _pillar('Safety ($demoSafetyGrade)', demoSafety),
      ],
    );
  }
}

// ---------- Vibe picker ----------

class DemoVibePicker extends StatefulWidget {
  const DemoVibePicker({super.key});

  @override
  State<DemoVibePicker> createState() => _DemoVibePickerState();
}

class _DemoVibePickerState extends State<DemoVibePicker> {
  final _picked = <String>{'Adventurer', 'Foodie', 'Music head'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("What's your vibe?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Pick up to 5. They show on your profile card.'),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final v in demoVibes)
            FilterChip(
              label: Text(v),
              selected: _picked.contains(v),
              onSelected: (on) => setState(() {
                if (!on) {
                  _picked.remove(v);
                } else if (_picked.length < 5) {
                  _picked.add(v);
                }
              }),
            ),
        ]),
      ]),
    );
  }
}
