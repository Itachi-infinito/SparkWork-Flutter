import 'package:flutter/material.dart';
class MatchPage extends StatelessWidget {
  final int participantId;
  final String participantName;
  const MatchPage({super.key, required this.participantId, required this.participantName});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Match!')), body: Center(child: Text('Match avec $participantName')));
}
