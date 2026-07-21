import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late AnimationController _radarController;
  
  late Animation<double> _fadeLogoAnimation;
  late Animation<double> _scaleLogoAnimation;
  late Animation<double> _pulseLogoAnimation;
  
  late Animation<Offset> _slideTextAnimation;
  late Animation<double> _fadeTextAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controlador principal para la entrada de elementos
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Controlador para la rotación del brillo de fondo
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Controlador dedicado para la onda de escaneo continuo del radar
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _fadeLogoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleLogoAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Efecto de pulso suave continuo después de escalar
    _pulseLogoAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _fadeTextAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _slideTextAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _mainController.forward();

    // Redirección tras 3.2 segundos
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF6EFE1),
      body: Stack(
        children: [
          // 1. Halo de Brillo Rotatorio de Fondo (Glow)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: Center(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            const Color(0xFFBF5B34).withOpacity(0.0),
                            const Color(0xFFBF5B34).withOpacity(isDark ? 0.14 : 0.08),
                            const Color(0xFFE0982F).withOpacity(isDark ? 0.12 : 0.06),
                            const Color(0xFF2F5D4C).withOpacity(isDark ? 0.14 : 0.08),
                            const Color(0xFFBF5B34).withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Contenido Central (Logo + Textos)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado con pulso, elasticidad y ondas de radar concéntricas continuas
                AnimatedBuilder(
                  animation: Listenable.merge([_mainController, _radarController]),
                  builder: (context, child) {
                    final scale = _scaleLogoAnimation.value * _pulseLogoAnimation.value;
                    return Opacity(
                      opacity: _fadeLogoAnimation.value,
                      child: Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ondas de radar continuas en el fondo
                            SizedBox(
                              width: 250,
                              height: 250,
                              child: CustomPaint(
                                painter: RadarScannerPainter(
                                  progress: _radarController.value,
                                  color: const Color(0xFFBF5B34),
                                ),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 155,
                    height: 155,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF131B26) : Colors.white,
                      border: Border.all(
                        color: const Color(0xFFBF5B34).withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBF5B34).withOpacity(isDark ? 0.35 : 0.15),
                          blurRadius: 28,
                          spreadRadius: 3,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.map,
                          color: Color(0xFFBF5B34),
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Título y Subtítulo deslizantes
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeTextAnimation.value,
                      child: FractionalTranslation(
                        translation: _slideTextAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        'Vía Libre',
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alertas comunitarias en tiempo real',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : const Color(0xFF78716C),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 64),

                // Indicador de carga ultra fino y minimalista
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFBF5B34),
                    strokeWidth: 2.0,
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

class RadarScannerPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarScannerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Primer anillo
    final paint1 = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, maxRadius * progress, paint1);

    // Segundo anillo (desfase de 0.5)
    final progress2 = (progress + 0.5) % 1.0;
    final paint2 = Paint()
      ..color = color.withOpacity((1.0 - progress2).clamp(0.0, 1.0) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, maxRadius * progress2, paint2);
  }

  @override
  bool shouldRepaint(covariant RadarScannerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class Timer {
  Timer(Duration duration, VoidCallback callback) {
    Future.delayed(duration, callback);
  }
}
