import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';

class MatchPage extends ConsumerStatefulWidget {
  final String matchId;
  final String jobOfferTitle;
  final String companyName;

  const MatchPage({
    super.key,
    required this.matchId,
    required this.jobOfferTitle,
    required this.companyName,
  });

  @override
  ConsumerState<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends ConsumerState<MatchPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _textCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _scaleAnim;
  late Animation<double> _titleAnim;
  late Animation<double> _subtitleAnim;
  late Animation<double> _buttonsAnim;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _titleAnim = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _subtitleAnim = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );
    _buttonsAnim = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _entranceCtrl.forward().then((_) => _textCtrl.forward());
    _markSeen();
  }

  Future<void> _markSeen() async {
    final isCandidate = ref.read(sessionProvider).isCandidate;
    await ref.read(matchRepositoryProvider).markAnimationSeen(widget.matchId, isCandidate: isCandidate);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Particules de fond
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (ctx, _) => CustomPaint(
                painter: _ParticlesPainter(_particleCtrl.value),
                size: MediaQuery.of(context).size,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône avec anneaux pulsants
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (ctx, _) => CustomPaint(
                              size: const Size(200, 200),
                              painter: _PulseRingsPainter(_pulseCtrl.value),
                            ),
                          ),
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2.5),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Titre
                    FadeTransition(
                      opacity: _titleAnim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _textCtrl,
                          curve: const Interval(0.0, 0.5,
                              curve: Curves.easeOut),
                        )),
                        child: const Text(
                          "C'est un Match !",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sous-titre
                    FadeTransition(
                      opacity: _subtitleAnim,
                      child: Text(
                        'Vous avez matché avec\n${widget.companyName}\npour le poste de\n${widget.jobOfferTitle}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Boutons
                    FadeTransition(
                      opacity: _buttonsAnim,
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context
                                  .push('/messages/${widget.matchId}'),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Envoyer un message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                minimumSize:
                                    const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white, width: 1.5),
                                minimumSize:
                                    const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                              child:
                                  const Text('Continuer à swiper'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Anneaux qui pulsent autour de l'icône
class _PulseRingsPainter extends CustomPainter {
  final double progress;
  _PulseRingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final p = ((progress + i / 3) % 1.0);
      final radius = 55 + (maxRadius - 55) * p;
      final opacity = (1.0 - p) * 0.45;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingsPainter old) => old.progress != progress;
}

// Particules scintillantes en arrière-plan
class _ParticlesPainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = List.generate(
    30,
    (i) => _Particle(i),
  );

  _ParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.offset) % 1.0;
      final x = p.x * size.width;
      final y = size.height - (t * size.height * 1.2) + p.startY * size.height;
      final opacity = t < 0.2
          ? t / 0.2
          : t > 0.8
              ? (1.0 - t) / 0.2
              : 1.0;

      canvas.drawCircle(
        Offset(x, y % size.height),
        p.radius,
        Paint()..color = Colors.white.withOpacity(opacity * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.progress != progress;
}

class _Particle {
  final double x;
  final double startY;
  final double offset;
  final double radius;

  _Particle(int seed)
      : x = ((seed * 137.5) % 100) / 100,
        startY = ((seed * 93.7) % 100) / 100,
        offset = ((seed * 47.3) % 100) / 100,
        radius = 1.5 + ((seed * 31.1) % 10) / 10 * 2.5;
}