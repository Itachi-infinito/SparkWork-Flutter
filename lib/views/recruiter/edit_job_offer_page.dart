import 'package:flutter/material.dart';
class EditJobOfferPage extends StatelessWidget {
  final int offerId;
  const EditJobOfferPage({super.key, required this.offerId});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Modifier offre')), body: Center(child: Text('Offre #$offerId')));
}
