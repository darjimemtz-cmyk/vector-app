import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidColors {
  static const Color luminousBlueLight = Color(0xFF1E40FF);
  static const Color electricJadeLight = Color(0xFF00D09C);
  static const Color backgroundLight = Color(0xFFF4F6FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF334155);
  static const Color coralLight = Color(0xFFFF4D6D);
  static const Color indigoAccentLight = Color(0xFF6366F1);

  static const Color luminousBlueDark = Color(0xFF4F75FF);
  static const Color electricJadeDark = Color(0xFF00D09C);
  static const Color backgroundDark = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF141C2E);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color coralDark = Color(0xFFFF6B8A);
  static const Color indigoAccentDark = Color(0xFF818CF8);

  static const Color meshBlue = Color(0xFF1E40FF);
  static const Color meshJade = Color(0xFF00D09C);
  static const Color meshIndigo = Color(0xFF6366F1);
}

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;
  final Color? tintColor;
  final double blurSigma;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 26,
    this.padding,
    this.margin,
    this.isDark = false,
    this.tintColor,
    this.blurSigma = 22,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: _buildAmbientShadows(),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            foregroundPainter: _SpecularRimPainter(
              borderRadius: borderRadius,
              isDark: isDark,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: effectiveBorderRadius,
                gradient: _buildInternalGradient(),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _buildInternalGradient() {
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xCC141C2E),
          Color(0xB30C1220),
        ],
        stops: [0.0, 1.0],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xD9FFFFFF),
          Color(0x9EEAF1FF),
        ],
        stops: [0.0, 1.0],
      );
    }
  }

  List<BoxShadow> _buildAmbientShadows() {
    final shadowColor = LiquidColors.luminousBlueLight.withOpacity(isDark ? 0.25 : 0.10);
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: -2,
      ),
    ];
  }
}

class _SpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final bool isDark;

  _SpecularRimPainter({
    required this.borderRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final rimGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(isDark ? 0.35 : 0.85),
        Colors.white.withOpacity(0.05),
      ],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _SpecularRimPainter &&
        (oldDelegate.borderRadius != borderRadius ||
         oldDelegate.isDark != isDark);
  }
}

class LiquidMeshBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const LiquidMeshBackground({
    super.key,
    required this.child,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? LiquidColors.backgroundDark : LiquidColors.backgroundLight,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _buildMeshSphere(
              diameter: 320,
              color: LiquidColors.meshBlue,
              opacity: 0.22,
            ),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child: _buildMeshSphere(
              diameter: 400,
              color: LiquidColors.meshJade,
              opacity: 0.22,
            ),
          ),
          Positioned(
            top: 200,
            left: -60,
            child: _buildMeshSphere(
              diameter: 280,
              color: LiquidColors.meshIndigo,
              opacity: 0.18,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildMeshSphere({
    required double diameter,
    required Color color,
    required double opacity,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: 120,
            spreadRadius: 20,
            offset: Offset.zero,
          ),
          BoxShadow(
            color: color.withOpacity(opacity * 0.5),
            blurRadius: 200,
            spreadRadius: 60,
            offset: Offset.zero,
          ),
        ],
      ),
    );
  }
}

class LiquidSegmentedPill extends StatefulWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;
  final double height;
  final double borderRadius;

  const LiquidSegmentedPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.isDark = false,
    this.height = 48,
    this.borderRadius = 30,
  });

  @override
  State<LiquidSegmentedPill> createState() => _LiquidSegmentedPillState();
}

class _LiquidSegmentedPillState extends State<LiquidSegmentedPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant LiquidSegmentedPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor = widget.isDark
        ? LiquidColors.luminousBlueDark
        : LiquidColors.luminousBlueLight;

    return LiquidGlassContainer(
      borderRadius: widget.borderRadius,
      blurSigma: 18,
      isDark: widget.isDark,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / widget.labels.length;
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final targetLeft = widget.selectedIndex * itemWidth;
                    final currentLeft = _animation.value * targetLeft +
                        (1 - _animation.value) * (widget.selectedIndex == 0 ? 0 : targetLeft);

                    return Positioned(
                      left: currentLeft,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.borderRadius - 4),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              indicatorColor.withOpacity(0.9),
                              indicatorColor.withOpacity(0.6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: indicatorColor.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: List.generate(widget.labels.length, (index) {
                    final isSelected = index == widget.selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onChanged(index),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (widget.isDark ? Colors.white : Colors.white)
                                  : (widget.isDark
                                      ? LiquidColors.textSecondaryDark
                                      : LiquidColors.textSecondaryLight),
                              letterSpacing: 0.3,
                            ),
                            child: Text(widget.labels[index]),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LiquidPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDark;
  final bool isLoading;
  final IconData? icon;
  final double borderRadius;
  final double height;

  const LiquidPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isDark = false,
    this.isLoading = false,
    this.icon,
    this.borderRadius = 28,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final coralColor = isDark ? LiquidColors.coralDark : LiquidColors.coralLight;
    final luminousBlue = isDark ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight;
    final electricJade = isDark ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight;

    return SizedBox(
      height: height,
      child: LiquidGlassContainer(
        borderRadius: borderRadius,
        blurSigma: 14,
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: isPrimary
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [luminousBlue, electricJade],
                      )
                    : LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          coralColor.withOpacity(0.85),
                          coralColor.withOpacity(0.65),
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (isPrimary ? luminousBlue : coralColor).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: -3,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidIepsBadge extends StatelessWidget {
  final String text;
  final bool isDark;

  const LiquidIepsBadge({
    super.key,
    required this.text,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final jadeColor = isDark ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            jadeColor.withOpacity(0.25),
            jadeColor.withOpacity(0.12),
          ],
        ),
        border: Border.all(
          color: jadeColor.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: jadeColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class LiquidProductCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String? quantity;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool gravaIeps;
  final bool isDark;
  final bool isCatalog;

  const LiquidProductCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    this.quantity,
    this.onTap,
    this.onIncrement,
    this.onDecrement,
    this.gravaIeps = false,
    this.isDark = false,
    this.isCatalog = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight;
    final secondaryColor = isDark ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight;

    return LiquidGlassContainer(
      borderRadius: 20,
      blurSigma: 14,
      isDark: isDark,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E2A4A).withOpacity(0.8),
                              const Color(0xFF141C2E).withOpacity(0.6),
                            ]
                          : [
                              Colors.white.withOpacity(0.7),
                              Colors.white.withOpacity(0.35),
                            ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(isDark ? 0.12 : 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    isCatalog ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined,
                    color: secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (gravaIeps)
                            LiquidIepsBadge(text: 'IEPS 8%', isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (isCatalog && onIncrement != null) ...[
                      const SizedBox(height: 8),
                      _QtyButton(
                        icon: Icons.add,
                        onPressed: onIncrement,
                        isDark: isDark,
                      ),
                    ] else if (quantity != null && !isCatalog) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtyButton(
                            icon: Icons.remove,
                            onPressed: onDecrement,
                            isDark: isDark,
                          ),
                          Container(
                            width: 44,
                            alignment: Alignment.center,
                            child: Text(
                              quantity!,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.add,
                            onPressed: onIncrement,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;

  const _QtyButton({
    required this.icon,
    this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(isDark ? 0.12 : 0.25),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.18 : 0.35),
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class LiquidDialog extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double borderRadius;

  const LiquidDialog({
    super.key,
    required this.child,
    this.isDark = false,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LiquidGlassContainer(
        borderRadius: borderRadius,
        blurSigma: 24,
        isDark: isDark,
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class LiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool isDark;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onLeadingPress;

  const LiquidAppBar({
    super.key,
    required this.title,
    this.actions,
    this.isDark = false,
    this.onThemeToggle,
    this.onLeadingPress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight;
    final iconColor = isDark ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.menu, color: iconColor, size: 28),
        onPressed: onLeadingPress,
      ),
      actions: [
        if (onThemeToggle != null)
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: iconColor,
              size: 26,
            ),
            onPressed: onThemeToggle,
            tooltip: isDark ? 'Modo claro' : 'Modo noche',
          ),
        ...?actions,
      ],
      iconTheme: IconThemeData(color: iconColor),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
