import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1f2021)
        : const Color(0xFFefedee);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: bgColor,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset('assets/icon/icon-512.png', height: 128),
          ),
        ),
      ),
    );
  }
}
