import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/session_provider.dart';
import '../widgets/sunset_backdrop.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final session = context.read<SessionProvider>();
      final isLoggedIn = session.isLoggedIn;
      final destination = isLoggedIn
          ? SessionProvider.routeForRole(session.effectiveRole)
          : '/onboarding';
      Navigator.of(context).pushReplacementNamed(destination);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SunsetBackdrop(horizon: 0.68),
          Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // A custom elegant food/heart shape for Cravey logo
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.primaryDark, width: 3),
                        boxShadow: const [
                          BoxShadow(color: AppTheme.primaryDark, offset: Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 55,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Wordmark: cream letters with a brick shadow, like a postcard
                    Text(
                      "Cravey",
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: const Color(0xFFFFF6D4),
                            fontSize: 54,
                            letterSpacing: 1.5,
                            shadows: const [Shadow(color: AppTheme.primaryDark, offset: Offset(3, 4))],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Satisfy Your Desires",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: 3,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
        ],
      ),
    );
  }
}
