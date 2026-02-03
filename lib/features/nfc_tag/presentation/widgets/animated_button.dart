// lib/features/nfc_tag/presentation/widgets/animated_button.dart

import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AnimatedButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _pressed = false;

  void _updatePressed(bool isPressed) {
    setState(() => _pressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _updatePressed(true),
      onPointerUp: (_) => _updatePressed(false),
      onPointerCancel: (_) => _updatePressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ElevatedButton.icon(
          icon: Icon(widget.icon, color: Colors.white),
          label:
              Text(widget.label, style: const TextStyle(color: Colors.white)),
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            minimumSize: const Size(220, 55),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedButton2 extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const AnimatedButton2({
    required this.color,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  State<AnimatedButton2> createState() => _AnimatedButton2State();
}

class _AnimatedButton2State extends State<AnimatedButton2> {
  bool _pressed = false;

  void _updatePressed(bool isPressed) {
    setState(() => _pressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _updatePressed(true),
      onPointerUp: (_) => _updatePressed(false),
      onPointerCancel: (_) => _updatePressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ElevatedButton.icon(
          label:
              Text(widget.label, style: const TextStyle(color: Colors.white)),
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            minimumSize: const Size(220, 55),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedButton3 extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const AnimatedButton3({
    required this.color,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  State<AnimatedButton3> createState() => _AnimatedButton3State();
}

class _AnimatedButton3State extends State<AnimatedButton3> {
  bool _pressed = false;

  void _updatePressed(bool isPressed) {
    setState(() => _pressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _updatePressed(true),
      onPointerUp: (_) => _updatePressed(false),
      onPointerCancel: (_) => _updatePressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ElevatedButton.icon(
          label: Text(widget.label, style: TextStyle(color: widget.color)),
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(220, 55),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side:
                  BorderSide(color: widget.color, width: 2), // 🔹 Border added
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
