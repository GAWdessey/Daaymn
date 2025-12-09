import 'dart:async';
import 'dart:ui' as ui;
import 'package:daaymn/services/promo_code_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPollOption {
  final String id;
  final String title;
  final String? subtitle;
  int votes;

  CommunityPollOption({
    required this.id,
    required this.title,
    this.subtitle,
    this.votes = 0,
  });

  factory CommunityPollOption.fromMap(Map<String, dynamic> map) {
    return CommunityPollOption(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      votes: map['votes'] ?? 0,
    );
  }
}

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  late final Future<void> _initialLoadFuture;
  StreamSubscription<List<Map<String, dynamic>>>? _pollSubscription;
  List<CommunityPollOption> _pollOptions = [];
  String? _activePollId;
  String? _userVotedOptionId;
  String? _error;
  final _promoCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialLoadFuture = _fetchInitialData();
  }

  @override
  void dispose() {
    if (_pollSubscription != null) {
      _pollSubscription!.cancel();
    }
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final now = DateTime.now().toIso8601String();
      final List<dynamic> pollsResponse = await Supabase.instance.client
          .from('polls')
          .select('id')
          .lte('start_date', now)
          .gte('end_date', now)
          .limit(1);

      if (pollsResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'No active poll found for the current period.';
          });
        }
        return;
      }
      _activePollId = pollsResponse.first['id'];

      final optionsResponse = await Supabase.instance.client
          .from('poll_options')
          .select()
          .eq('poll_id', _activePollId!);

      final options = (optionsResponse as List)
          .map((data) => CommunityPollOption.fromMap(data))
          .toList();

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final voteResponse = await Supabase.instance.client
          .from('poll_votes')
          .select('option_id')
          .eq('poll_id', _activePollId!)
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _pollOptions = options;
          if (voteResponse != null) {
            _userVotedOptionId = voteResponse['option_id'];
          }
        });
        _listenToPollChanges();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _listenToPollChanges() {
    if (_activePollId == null) return;
    _pollSubscription = Supabase.instance.client
        .from('poll_options')
        .stream(primaryKey: ['id']).listen((payload) {
      if (mounted) {
        var optionsHaveChanged = false;
        var newPollOptions = List<CommunityPollOption>.from(_pollOptions);

        for (var updatedData in payload) {
          if (updatedData['poll_id'] == _activePollId) {
            final updatedOption = CommunityPollOption.fromMap(updatedData);
            final index = newPollOptions.indexWhere((opt) => opt.id == updatedOption.id);
            if (index != -1) {
              if(newPollOptions[index].votes != updatedOption.votes) {
                newPollOptions[index] = updatedOption;
                optionsHaveChanged = true;
              }
            }
          }
        }
        if(optionsHaveChanged) {
          setState(() {
            _pollOptions = newPollOptions;
          });
        }
      }
    });
  }

  Future<void> _handleVote(CommunityPollOption selectedOption) async {
    if (_userVotedOptionId != null) {
      return;
    }

    setState(() {
      _userVotedOptionId = selectedOption.id;
    });

    try {
      await Supabase.instance.client.functions.invoke(
        'cast-vote',
        body: {'option_id': selectedOption.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your vote has been counted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userVotedOptionId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cast vote: '+e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPromoRedeemedDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withAlpha(200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text(
            'Daaymn! A free report, you say?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Bungee',
              color: Colors.white,
            ),
          ),
          content: const Text(
            "Listen up. This free report is the real deal, but it's only as good as the tea you give it. To get a score that's actually worth a Daaymn, you gotta play the game first. Like some profiles, get some matches, let your vibe be known. Use this power wisely.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("I get it, let's go!"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLastMonthsWinner() async {
    try {
      final now = DateTime.now();
      final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

      // Step 1: Find the poll from last month.
      final pollsResponse = await Supabase.instance.client
          .from('polls')
          .select('id')
          .lt('end_date', firstDayOfCurrentMonth.toIso8601String())
          .order('end_date', ascending: false)
          .limit(1);

      if (pollsResponse.isEmpty) {
        _showWinnerDialog(null);
        return;
      }

      final lastMonthPollId = pollsResponse.first['id'];

      // Step 2: Get all options for that poll, sorted by votes.
      final optionsResponse = await Supabase.instance.client
          .from('poll_options')
          .select()
          .eq('poll_id', lastMonthPollId)
          .order('votes', ascending: false);

      if (optionsResponse.isEmpty) {
        _showWinnerDialog(null);
      } else {
        // Step 3: Process the results.
        final winnerOptions = optionsResponse.map((data) => CommunityPollOption.fromMap(data)).toList();
        final winner = winnerOptions.first;
        final totalVotes = winnerOptions.fold(0, (sum, item) => sum + item.votes);
        _showWinnerDialog(winner, totalVotes: totalVotes);
      }
    } catch (e) {
       _showWinnerDialog(null, error: e.toString());
    }
  }

  void _showWinnerDialog(CommunityPollOption? winner, {int totalVotes = 0, String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Last Month's Winner"),
        content: error != null
            ? Text("Error: $error")
            : winner != null
                ? _buildPollOption(winner, isWinnerDialog: true, totalVotesOverride: totalVotes)
                : const Text("No winning poll found for last month."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'Daaymn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Pacifico',
            ),
          ),
        ),
      ),
      body: FutureBuilder(
        future: _initialLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
             return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: '+_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
           if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: '+snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Daaymn Polls',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Bungee',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome to the Daaymn Swing! Tap on an option to cast your vote. You have a hand in shaping the future of the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                if (_pollOptions.isEmpty)
                  const Center(child: Text("No poll options available.", style: TextStyle(color: Colors.grey)))
                else
                 ..._pollOptions.map((option) => _buildPollOption(option)),
                const SizedBox(height: 24),
                _buildVotingStatus(),
                const SizedBox(height: 24),
                 ElevatedButton(
                  onPressed: _showLastMonthsWinner,
                  child: const Text("See Last Month's Winner"),
                ),
                const SizedBox(height: 24),
                _buildPromoCodeSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPollOption(CommunityPollOption option, {bool isWinnerDialog = false, int? totalVotesOverride}) {
    final int totalVotes = totalVotesOverride ?? _pollOptions.fold(0, (sum, item) => sum + item.votes);
    final double percentage = totalVotes == 0 ? 0 : (option.votes / totalVotes);
    final bool hasVotedForThis = _userVotedOptionId == option.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: isWinnerDialog ? null : () => _handleVote(option),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: hasVotedForThis ? Colors.green : Colors.grey.shade300,
              width: hasVotedForThis ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        if (option.subtitle != null)
                          Text(option.subtitle!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (hasVotedForThis)
                    const Icon(Icons.check_circle, color: Colors.green),
                  Text(''+option.votes.toString()+' votes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              _buildVoteProgressBar(percentage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteProgressBar(double percentage) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: constraints.maxWidth * percentage,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVotingStatus() {
    final String statusText = _userVotedOptionId == null
        ? 'The current poll ends on the 1st of next month.'
        : 'Thanks for voting! Come back next month for a new poll.';

    final IconData statusIcon = _userVotedOptionId == null ? Icons.info_outline : Icons.check_circle_outline;
    final Color statusColor = _userVotedOptionId == null ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Consumer<PromoCodeService>(
      builder: (context, promoService, child) {
        return Column(
          children: [
            TextField(
              controller: _promoCodeController,
              decoration: const InputDecoration(
                labelText: 'Enter Promo Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (promoService.isRedeeming)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: () async {
                  final code = _promoCodeController.text.trim();
                  if (code.isNotEmpty) {
                    final success = await promoService.redeemCode(code);
                    if (success && mounted) {
                      _showPromoRedeemedDialog();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(promoService.error ?? 'Failed to redeem promo code.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Redeem'),
              ),
            if (promoService.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  promoService.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }
}
