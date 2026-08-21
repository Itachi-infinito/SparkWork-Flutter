import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Pluie de confettis plein écran pour les moments mémorables (match,
/// embauche confirmée). À empiler dans un Stack au-dessus du contenu ;
/// démarre automatiquement à l'affichage.
class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  const ConfettiOverlay({super.key, this.duration = const Duration(seconds: 2)});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: widget.duration)..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deux canons en haut de l'écran, orientés vers le bas en éventail —
    // couvre toute la largeur sans masquer le contenu (IgnorePointer).
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: pi / 3, // vers le bas-droite
              emissionFrequency: 0.06,
              numberOfParticles: 8,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              colors: const [
                Color(0xFF7C3AED), // violet Spark
                Color(0xFFEC4899), // rose Spark
                Colors.amber,
                Colors.white,
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: 2 * pi / 3, // vers le bas-gauche
              emissionFrequency: 0.06,
              numberOfParticles: 8,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              colors: const [
                Color(0xFF7C3AED),
                Color(0xFFEC4899),
                Colors.amber,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
