import 'package:flutter/material.dart';

/// Un contenedor interactivo que ofrece un suave acercamiento (zoom/scale),
/// elevación de sombra y resaltado de borde al pasar el cursor (hover),
/// adaptándose automáticamente al modo Claro u Oscuro.
class HoverScaleCard extends StatefulWidget {
  final Widget child;
  final double scaleFactor;
  final double translateY;
  final Duration duration;
  final BoxDecoration? baseDecoration;
  final BoxDecoration? hoverDecoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final MouseCursor cursor;
  final bool enableLift;

  const HoverScaleCard({
    super.key,
    required this.child,
    this.scaleFactor = 1.02,
    this.translateY = -3.0,
    this.duration = const Duration(milliseconds: 220),
    this.baseDecoration,
    this.hoverDecoration,
    this.padding,
    this.margin,
    this.onTap,
    this.cursor = SystemMouseCursors.basic,
    this.enableLift = true,
  });

  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BoxDecoration? adaptDec(BoxDecoration? dec) {
      if (dec == null) return null;
      if (isDark && (dec.color == Colors.white || dec.color == const Color(0xFFF8FAFC) || dec.color == const Color(0xFFF4F6F9) || dec.color == const Color(0xFFEFF6FF))) {
        return dec.copyWith(
          color: const Color(0xFF1E293B),
        );
      }
      return dec;
    }

    final effectiveBaseDec = adaptDec(widget.baseDecoration) ??
        BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        );

    final effectiveHoverDec = adaptDec(widget.hoverDecoration) ??
        BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1877F2).withValues(alpha: isDark ? 0.28 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        );

    final Matrix4 transform = _isHovered
        ? (Matrix4.identity()
          ..translate(0.0, widget.enableLift ? widget.translateY : 0.0)
          ..scale(widget.scaleFactor))
        : Matrix4.identity();

    final animatedContainer = AnimatedContainer(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      margin: widget.margin,
      transform: transform,
      transformAlignment: Alignment.center,
      decoration: _isHovered ? effectiveHoverDec : effectiveBaseDec,
      child: widget.child,
    );

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              child: animatedContainer,
            )
          : animatedContainer,
    );
  }
}

/// Un micro-envoltorio de zoom suave para elementos más pequeños (chips, píldoras, iconos).
class HoverZoom extends StatefulWidget {
  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  const HoverZoom({
    super.key,
    required this.child,
    this.scaleFactor = 1.06,
    this.duration = const Duration(milliseconds: 180),
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverZoom> createState() => _HoverZoomState();
}

class _HoverZoomState extends State<HoverZoom> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _isHovered ? widget.scaleFactor : 1.0,
                duration: widget.duration,
                curve: Curves.easeOutCubic,
                child: widget.child,
              ),
            )
          : AnimatedScale(
              scale: _isHovered ? widget.scaleFactor : 1.0,
              duration: widget.duration,
              curve: Curves.easeOutCubic,
              child: widget.child,
            ),
    );
  }
}
