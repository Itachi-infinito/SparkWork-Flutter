import 'package:flutter/material.dart';
class CandidateDetailPage extends StatelessWidget {
  final int candidateId;
  const CandidateDetailPage({super.key, required this.candidateId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Candidat')), body: Center(child: Text('Candidat #$candidateId')));
}
