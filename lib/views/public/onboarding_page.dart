import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      gradient: [Color(0xFF7C4DFF), Color(0xFF5E35B1)],
      icon: Icons.swipe,
      title: 'Swipez',
      subtitle:
          'Découvrez des offres d\'emploi et des candidats Horeca en quelques glissements.',
    ),
    _OnboardingSlide(
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
      icon: Icons.favorite_rounded,
      title: 'Matchez',
      subtitle:
          'Quand l\'intérêt est mutuel, c\'est un SparkWork Match ! Simple et efficace.',
    ),
    _OnboardingSlide(
      gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      icon: Icons.chat_bubble_rounded,
      title: 'Échangez',
      subtitle:
          'Discutez directement avec vos matches et décrochez votre prochain poste.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go('/welcome');
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) =>
                _SlidePage(slide: _slides[i]),
          ),

          // Skip button
          if (_currentPage < _slides.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Passer',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 32,
            right: 32,
            child: Column(
              children: [
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          _slides[_currentPage].gradient[0],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _currentPage < _slides.length - 1
                          ? 'Suivant'
                          : 'Commencer',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _OnboardingSlide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: slide.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Icon circle
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slide.icon,
                        color: Colors.white, size: 52),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Title
              Text(
                slide.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardingSlide({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}