import 'package:flutter/material.dart';
class ConversationDetailPage extends StatelessWidget {
  final int matchId;
  const ConversationDetailPage({super.key, required this.matchId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Conversation')), body: Center(child: Text('Match #$matchId')));
}
