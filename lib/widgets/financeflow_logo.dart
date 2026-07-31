import 'package:flutter/material.dart';

class FinanceFlowLogo extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color? accentColor;
  final bool isDarkMode;

  const FinanceFlowLogo({
    super.key,
    this.size = 28.0,
    required this.primaryColor,
    this.accentColor,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? const Color(0xFFF59E0B); // Gold/Amber accent

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FinanceFlowLogoPainter(
          primaryColor: primaryColor,
          accentColor: effectiveAccent,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}

class _FinanceFlowLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final bool isDarkMode;

  _FinanceFlowLogoPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Wallet Body (Silver/White base with Primary Tint gradient)
    final walletRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.18, w * 0.76, h * 0.64),
      Radius.circular(w * 0.16),
    );

    final walletPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFFFFFFFF),
          isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(walletRect.outerRect);

    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08);

    // Draw Wallet Shadow
    canvas.drawRRect(walletRect.shift(Offset(0, h * 0.04)), shadowPaint);
    // Draw Wallet Body
    canvas.drawRRect(walletRect, walletPaint);

    // Wallet Top Line Accent
    final topLinePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;

    final topLinePath = Path()
      ..moveTo(w * 0.22, h * 0.28)
      ..lineTo(w * 0.78, h * 0.28);
    canvas.drawPath(topLinePath, topLinePaint);

    // Wallet Clasp Button
    final claspPaint = Paint()..color = primaryColor;
    canvas.drawCircle(Offset(w * 0.76, h * 0.52), w * 0.06, claspPaint);
    canvas.drawCircle(Offset(w * 0.76, h * 0.52), w * 0.025, Paint()..color = Colors.white);

    // 2. Draw Upward Growth Arrow (Dynamic Theme Gradient)
    final arrowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          accentColor,
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowPath = Path()
      ..moveTo(w * 0.10, h * 0.78)
      ..lineTo(w * 0.38, h * 0.44)
      ..lineTo(w * 0.54, h * 0.58)
      ..lineTo(w * 0.88, h * 0.18);

    canvas.drawPath(arrowPath, arrowPaint);

    // Arrow Head Tip Triangle
    final tipPath = Path()
      ..moveTo(w * 0.90, h * 0.14)
      ..lineTo(w * 0.70, h * 0.16)
      ..lineTo(w * 0.86, h * 0.32)
      ..close();

    final tipPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(tipPath, tipPaint);

    // 3. Draw Security Shield Emblem (Bottom Right)
    final shieldWidth = w * 0.28;
    final shieldHeight = h * 0.32;
    final shieldLeft = w * 0.62;
    final shieldTop = h * 0.58;

    final shieldPath = Path()
      ..moveTo(shieldLeft + shieldWidth * 0.5, shieldTop)
      ..lineTo(shieldLeft + shieldWidth, shieldTop + shieldHeight * 0.25)
      ..quadraticBezierTo(
        shieldLeft + shieldWidth,
        shieldTop + shieldHeight * 0.75,
        shieldLeft + shieldWidth * 0.5,
        shieldTop + shieldHeight,
      )
      ..quadraticBezierTo(
        shieldLeft,
        shieldTop + shieldHeight * 0.75,
        shieldLeft,
        shieldTop + shieldHeight * 0.25,
      )
      ..close();

    final shieldPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          primaryColor.withOpacity(0.85),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(shieldLeft, shieldTop, shieldWidth, shieldHeight));

    // Draw Shield Shadow & Body
    canvas.drawPath(shieldPath.shift(Offset(0, h * 0.02)), Paint()..color = Colors.black.withOpacity(0.2));
    canvas.drawPath(shieldPath, shieldPaint);

    // Shield Inner Line Detail
    final shieldLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;

    final shieldInnerPath = Path()
      ..moveTo(shieldLeft + shieldWidth * 0.5, shieldTop + shieldHeight * 0.2)
      ..lineTo(shieldLeft + shieldWidth * 0.5, shieldTop + shieldHeight * 0.8);
    canvas.drawPath(shieldInnerPath, shieldLinePaint);
  }

  @override
  bool shouldRepaint(covariant _FinanceFlowLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
