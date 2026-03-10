import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final List<String> _typingTexts = [
    'Unified API Debugging.',
    'Distributed Tracing.',
    'Scenario Automation.',
    'Beyond Postman.'
  ];
  int _textIndex = 0;
  String _currentText = "";
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _startTyping();
  }

  void _startTyping() {
    int charIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (charIndex < _typingTexts[_textIndex].length) {
        setState(() {
          _currentText += _typingTexts[_textIndex][charIndex];
          charIndex++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentText = "";
              _textIndex = (_textIndex + 1) % _typingTexts.length;
            });
            _startTyping();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient/Grid
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, -0.8),
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A1A1A),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/grid_pattern.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          // Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildNavbar(context),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: TracelyTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: TracelyTheme.primaryColor.withOpacity(0.2)),
                          ),
                          child: const Text(
                            '🚀 NEW: Automated Trace Replay for CI/CD',
                            style: TextStyle(color: TracelyTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'See the Invisible.',
                          style: GoogleFonts.outfit(
                            fontSize: 84,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            letterSpacing: -2,
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: Text(
                            _currentText + (DateTime.now().second % 2 == 0 ? "|" : ""),
                            style: GoogleFonts.firaCode(
                              fontSize: 54,
                              fontWeight: FontWeight.w300,
                              color: TracelyTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'The end-to-end distributed tracing and API engineering platform\ndesigned for modern microservices architectures.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 20, height: 1.6),
                        ),
                        const SizedBox(height: 64),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/login'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Get Started Free'),
                            ),
                            const SizedBox(width: 24),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                side: const BorderSide(color: Colors.white24),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Book a Demo'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 120),
                        // Mock UI Preview or Stats
                        _buildHeroStats(),
                      ],
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

  Widget _buildNavbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
      child: Row(
        children: [
          const Icon(Icons.radar, color: TracelyTheme.primaryColor, size: 32),
          const SizedBox(width: 12),
          Text('Tracely', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
          const Spacer(),
          _NavLink('Platform'),
          _NavLink('Solutions'),
          _NavLink('Pricing'),
          _NavLink('Docs'),
          const SizedBox(width: 32),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 24),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HeroStatItem('10M+', 'Spans Processed'),
        const SizedBox(width: 64),
        _HeroStatItem('45ms', 'Avg. Recovery Time'),
        const SizedBox(width: 64),
        _HeroStatItem('100+', 'Integrations'),
      ],
    );
  }

  Widget _HeroStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 14)),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}
