import 'package:flutter/material.dart';
import 'package:kota_pf1_app/constants/const_colors.dart';
import 'package:kota_pf1_app/helpers/sync_service.dart';
import 'package:kota_pf1_app/pages/home/home_page.dart';
import 'package:kota_pf1_app/pages/login/login_page.dart';
import 'dart:math' as math;
import 'package:kota_pf1_app/constants/print_data.dart';

class SplashPage extends StatefulWidget {
  final bool isLoggedIn;
  const SplashPage({super.key, required this.isLoggedIn});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _bgAnimController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat(reverse: true);

  late final Animation<double> _bgAnim = CurvedAnimation(
    parent: _bgAnimController,
    curve: Curves.easeInOut,
  );

  late final AnimationController _logoAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _logoAnimController,
    curve: Curves.easeIn,
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
    CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Show updating indicator while syncing lookup data
      await SyncService().syncLookupData();
    } catch (_) {}

    if (!mounted) return;
    if (widget.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _logoAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;
          return Stack(
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ConstColors.themeColor,
                      ConstColors.themeColor.withOpacity(0.85),
                      ConstColors.themeColor.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              // Animated blobs
              Positioned(
                top: height * (0.08 + 0.02 * math.sin(_bgAnim.value * math.pi * 2)),
                left: width * (0.6 + 0.05 * math.cos(_bgAnim.value * math.pi)),
                child: _AnimatedBlob(size: width * 0.38, color: Colors.white.withOpacity(0.08), animation: _bgAnim),
              ),
              Positioned(
                bottom: height * (0.04 + 0.03 * math.cos(_bgAnim.value * math.pi * 2)),
                right: width * (0.5 + 0.05 * math.sin(_bgAnim.value * math.pi)),
                child: _AnimatedBlob(size: width * 0.3, color: Colors.white.withOpacity(0.06), animation: _bgAnim),
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Image.asset(PrintData.appLogoWhite, height: 96),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    const Text('Updating data...', style: TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final double size;
  final Color color;
  final Animation<double> animation;

  const _AnimatedBlob({required this.size, required this.color, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final transform = Matrix4.identity()
          ..translate(
            size * math.cos(animation.value * math.pi * 2),
            size * math.sin(animation.value * math.pi * 2),
          )
          ..rotateZ(animation.value * math.pi * 2);
        return Transform(
          transform: transform,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }
} 