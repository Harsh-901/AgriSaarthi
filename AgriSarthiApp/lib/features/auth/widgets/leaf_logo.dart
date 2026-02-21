import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LeafLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const LeafLogo({
    super.key,
    this.size = 80,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.5, size * 0.5),
          painter: LeafPainter(color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}

class LeafPainter extends CustomPainter {
  final Color color;

  LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    
    // Draw leaf outline
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // Starting from the bottom tip
    path.moveTo(centerX, size.height * 0.95);
    
    // Left curve of the leaf
    path.quadraticBezierTo(
      size.width * 0.1, size.height * 0.6,
      size.width * 0.15, size.height * 0.3,
    );
    
    // Top of the leaf
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.05,
      centerX, size.height * 0.05,
    );
    
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.05,
      size.width * 0.85, size.height * 0.3,
    );
    
    // Right curve of the leaf
    path.quadraticBezierTo(
      size.width * 0.9, size.height * 0.6,
      centerX, size.height * 0.95,
    );
    
    canvas.drawPath(path, paint);
    
    // Draw center vein
    final Path veinPath = Path();
    veinPath.moveTo(centerX, size.height * 0.15);
    veinPath.quadraticBezierTo(
      centerX * 1.1, size.height * 0.5,
      centerX, size.height * 0.85,
    );
    
    canvas.drawPath(veinPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
