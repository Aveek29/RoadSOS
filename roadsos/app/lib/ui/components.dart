import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────
//  GLASS CARD CUSTOM DECORATOR
// ─────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double borderRadius;
  final Color borderColor;
  final Color fillColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.blur = 16.0,
    this.borderRadius = 16.0,
    this.borderColor = const Color(0x122A4070),
    this.fillColor = const Color(0x0C0C1524),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          padding: padding,
          // A transparent Material sits between the coloured container and the
          // child so that children such as ListTile (which paint backgrounds and
          // ink splashes on their nearest Material ancestor) render and ripple
          // correctly instead of being hidden behind this DecoratedBox.
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SWIPE TO CONFIRM GESTURE BUTTON
// ─────────────────────────────────────────────

class SwipeToConfirmButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirm;
  final Color trackColor;
  final Color thumbColor;
  final IconData icon;

  const SwipeToConfirmButton({
    super.key,
    required this.text,
    required this.onConfirm,
    this.trackColor = const Color(0x1BFFFFFF),
    this.thumbColor = Colors.white,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> {
  double _dragProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDragWidth = constraints.maxWidth - 58; // 50 width + padding margins
        return Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: widget.trackColor,
            borderRadius: BorderRadius.circular(29),
            border: Border.all(color: Colors.white12, width: 1.2),
          ),
          child: Stack(
            children: [
              // Track Label
              Center(
                child: Opacity(
                  opacity: (1.0 - _dragProgress * 1.5).clamp(0.1, 1.0),
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              // Draggable Pill
              Positioned(
                left: 4 + (_dragProgress * maxDragWidth),
                top: 4,
                bottom: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragProgress = (_dragProgress + details.primaryDelta! / maxDragWidth).clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragProgress > 0.85) {
                      setState(() {
                        _dragProgress = 1.0;
                      });
                      widget.onConfirm();
                      Future.delayed(const Duration(milliseconds: 1000), () {
                        if (mounted) {
                          setState(() {
                            _dragProgress = 0.0;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        _dragProgress = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.thumbColor == Colors.white ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  EMERGENCY COUNTDOWN ANIMATED RING
// ─────────────────────────────────────────────

class CountdownRing extends StatelessWidget {
  final int remainingSeconds;
  final double progress;
  final Color color;

  const CountdownRing({
    super.key,
    required this.remainingSeconds,
    required this.progress,
    this.color = RoadSoSColors.accentRed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background shadow
        Container(
          width: 172,
          height: 172,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.22),
                blurRadius: 28,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        // Progress ring indicator
        SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(
            value: 1.0 - progress,
            strokeWidth: 8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: Colors.white.withOpacity(0.08),
            strokeCap: StrokeCap.round,
          ),
        ),
        // Central counter layout
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$remainingSeconds',
              style: const TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
              ),
            ),
            const Text(
              'SECONDS LEFT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SAFETY CHECKLIST ITEM TILE
// ─────────────────────────────────────────────

class ChecklistTile extends StatelessWidget {
  final String label;
  final bool isCompleted;

  const ChecklistTile({
    super.key,
    required this.label,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? RoadSoSColors.accentTeal.withOpacity(0.12) : Colors.white12,
              border: Border.all(
                color: isCompleted ? RoadSoSColors.accentTeal : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: isCompleted ? RoadSoSColors.accentTeal : Colors.transparent,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w500,
              color: isCompleted ? Colors.white : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PREMIUM SOS PULSING HERO SHIELD
// ─────────────────────────────────────────────

class SosPulseShield extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isListening;

  const SosPulseShield({
    super.key,
    this.onTap,
    this.isListening = false,
  });

  @override
  State<SosPulseShield> createState() => _SosPulseShieldState();
}

class _SosPulseShieldState extends State<SosPulseShield> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isListening) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SosPulseShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isListening ? RoadSoSColors.critical : Colors.grey.withOpacity(0.5);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 280,
        height: 280,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Concentric pulsing rings
            if (widget.isListening)
              ...List.generate(3, (index) {
                final delay = index * 0.33;
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    double progress = _pulseController.value + delay;
                    if (progress > 1.0) progress -= 1.0;
                    
                    final double scale = 1.0 + (progress * 0.8);
                    final double opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;
                    
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: activeColor.withOpacity(opacity),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(opacity * 0.25),
                              blurRadius: 16,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
              
            // Ambient inner glow
            if (widget.isListening)
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(0.25),
                      blurRadius: 36,
                      spreadRadius: 8,
                    )
                  ],
                ),
              ),

            // Red Center Button
            Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isListening
                      ? [const Color(0xFFFF5247), const Color(0xFFC41C1C)]
                      : [const Color(0xFF2E334D), const Color(0xFF181C30)],
                ),
                border: Border.all(
                  color: widget.isListening ? const Color(0xFFFF8B85) : Colors.white12,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(42, 48),
                      painter: ShieldPainter(
                        color: Colors.white,
                        strokeWidth: 3.0,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SOS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: widget.isListening ? Colors.white : Colors.white60,
                        letterSpacing: 1.0,
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

// ─────────────────────────────────────────────
//  SHIELD CUSTOM VECTOR PAINTER
// ─────────────────────────────────────────────

class ShieldPainter extends CustomPainter {
  final Color color;
  final Color fillColor;
  final double strokeWidth;

  ShieldPainter({
    required this.color,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Draw an elegant shield shape
    path.moveTo(size.width * 0.5, 0); // Top-center
    path.quadraticBezierTo(size.width * 0.85, 0, size.width * 0.9, size.height * 0.15); // Top-right curve
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.5, size.width * 0.85, size.height * 0.7); // Right-side slope
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.98, size.width * 0.5, size.height); // Bottom-center point
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.98, size.width * 0.15, size.height * 0.7); // Left slope
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.5, size.width * 0.1, size.height * 0.15); // Left-side slope
    path.quadraticBezierTo(size.width * 0.15, 0, size.width * 0.5, 0); // Top-left curve back to start
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
//  PREMIUM MOCK VECTOR MAP PREVIEW WIDGET
// ─────────────────────────────────────────────

class LiveMapPreview extends StatelessWidget {
  final double height;
  final bool showDirections;

  const LiveMapPreview({
    super.key,
    this.height = 220.0,
    this.showDirections = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF111625),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RoadSoSColors.borderDark, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Custom Painted Vector Map
            Positioned.fill(
              child: CustomPaint(
                painter: MapPainter(showRoute: showDirections),
              ),
            ),
            
            // Map Controls / Locate button
            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF151A2D),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            
            // Map Zoom controls
            Positioned(
              left: 14,
              bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151A2D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151A2D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MAP LAYOUT CUSTOM PAINTER
// ─────────────────────────────────────────────

class MapPainter extends CustomPainter {
  final bool showRoute;

  MapPainter({required this.showRoute});

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background (sleek dark map theme background)
    final bgPaint = Paint()..color = const Color(0xFF0F1423);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid lines for secondary details
    final gridPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1.0;
    
    const double gridSize = 30.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw secondary roads (Thin dark-grey/navy lines)
    final roadPaint = Paint()
      ..color = const Color(0xFF1B223D)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final primaryRoadPaint = Paint()
      ..color = const Color(0xFF262E52)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    // Draw some stylized street intersections
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.7), roadPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.65, size.height), roadPaint);

    // Primary diagonal highway
    canvas.drawLine(Offset(-20, size.height * 0.5), Offset(size.width + 20, size.height * 0.5), primaryRoadPaint);
    canvas.drawLine(Offset(size.width * 0.5, -20), Offset(size.width * 0.5, size.height + 20), primaryRoadPaint);

    // Overlay inner line for roads (to look like dual-tone highway lines)
    final innerHighwayPaint = Paint()
      ..color = const Color(0xFF101423)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(-20, size.height * 0.5), Offset(size.width + 20, size.height * 0.5), innerHighwayPaint);
    canvas.drawLine(Offset(size.width * 0.5, -20), Offset(size.width * 0.5, size.height + 20), innerHighwayPaint);

    // If directions requested, draw the green navigation path from A to B
    final Offset victimPoint = Offset(size.width * 0.65, size.height * 0.35);
    final Offset volunteerPoint = Offset(size.width * 0.35, size.height * 0.75);

    if (showRoute) {
      final routePaint = Paint()
        ..color = const Color(0xFF22C55E)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final routePath = Path();
      routePath.moveTo(volunteerPoint.dx, volunteerPoint.dy);
      // Route segment 1
      routePath.lineTo(size.width * 0.5, volunteerPoint.dy);
      // Route segment 2
      routePath.lineTo(size.width * 0.5, size.height * 0.5);
      // Route segment 3
      routePath.lineTo(victimPoint.dx, size.height * 0.5);
      // Route segment 4
      routePath.lineTo(victimPoint.dx, victimPoint.dy);

      // Draw active glowing background shadow for route
      final routeGlowPaint = Paint()
        ..color = const Color(0x3322C55E)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(routePath, routeGlowPaint);
      canvas.drawPath(routePath, routePaint);

      // Draw Volunteer position dot
      final helperDotPaint = Paint()..color = const Color(0xFF3B82F6);
      final helperRingPaint = Paint()
        ..color = const Color(0x333B82F6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(volunteerPoint, 14.0, helperRingPaint);
      canvas.drawCircle(volunteerPoint, 6.0, helperDotPaint);
    }

    // Draw Victim position (large red pin)
    final pinShadowPaint = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(victimPoint.dx, victimPoint.dy + 8), width: 14, height: 6),
      pinShadowPaint,
    );

    final pinPaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..style = PaintingStyle.fill;
    final pinOutlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pinPath = Path();
    pinPath.moveTo(victimPoint.dx, victimPoint.dy);
    // Draw tear drop shape pin
    pinPath.cubicTo(
      victimPoint.dx - 12, victimPoint.dy - 12,
      victimPoint.dx - 10, victimPoint.dy - 24,
      victimPoint.dx, victimPoint.dy - 24,
    );
    pinPath.cubicTo(
      victimPoint.dx + 10, victimPoint.dy - 24,
      victimPoint.dx + 12, victimPoint.dy - 12,
      victimPoint.dx, victimPoint.dy,
    );
    pinPath.close();

    canvas.drawPath(pinPath, pinPaint);
    canvas.drawPath(pinPath, pinOutlinePaint);

    // Inner white circle of pin
    canvas.drawCircle(Offset(victimPoint.dx, victimPoint.dy - 14), 4.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
//  STATUS CHIP WIDGET FOR TELEMETRY
// ─────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String label;
  final String status;
  final IconData icon;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE SECTION HEADER
// ─────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        if (actionText != null && onActionTap != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: RoadSoSColors.critical,
              ),
            ),
          ),
      ],
    );
  }
}


