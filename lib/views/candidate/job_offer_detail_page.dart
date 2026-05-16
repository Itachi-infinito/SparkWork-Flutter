import 'package:flutter/material.dart';
class JobOfferDetailPage extends StatelessWidget {
  final int offerId;
  const JobOfferDetailPage({super.key, required this.offerId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Offre')), body: Center(child: Text('Offre #$offerId')));
}
