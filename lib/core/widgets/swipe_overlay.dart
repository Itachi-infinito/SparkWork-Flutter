import 'package:flutter/material.dart';

enum SwipeOverlayType { like, pass, superLike, none }

class SwipeOverlay extends StatelessWidget {
  final SwipeOverlayType type;

  const SwipeOverlay({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == SwipeOverlayType.none) return const SizedBox.shrink();

    final config = _config[type]!;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: config['color'] as Color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(config['icon'] as IconData, color: Colors.white, size: 56),
              const SizedBox(height: 8),
              Text(
                config['label'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _config = {
    SwipeOverlayType.like: {
      'color': Color(0xCC10B981),
      'icon': Icons.favorite,
      'label': 'LIKE',
    },
    SwipeOverlayType.pass: {
      'color': Color(0xCCEF4444),
      'icon': Icons.close,
      'label': 'PASS',
    },
    SwipeOverlayType.superLike: {
      'color': Color(0xCCF59E0B),
      'icon': Icons.bolt,
      'label': 'SUPER',
    },
  };
}