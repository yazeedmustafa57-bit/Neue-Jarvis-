import 'dart:math';
import 'package:flutter/material.dart';

class NeonContainer extends StatefulWidget {
  final String title;
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const NeonContainer({
    super.key,
    required this.title,
    required this.child,
    this.height,
    this.padding,
  });

  @override
  State<NeonContainer> createState() => _NeonContainerState();
}

class _NeonContainerState extends State<NeonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_pulseController);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * sin(_pulseAnim.value * pi);
        final alpha = 40 + (30 * pulse).toInt();
        final alpha2 = (alpha * 0.5).toInt();

        return Container(
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color.fromRGBO(255, 120, 20, alpha),
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Color.fromRGBO(255, 180, 60, alpha2),
                width: 1,
              ),
              color: const Color.fromRGBO(8, 2, 12, 200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color.fromRGBO(255, 120, 20, 80),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    '  ▸ ${widget.title}',
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 140, 30, 200),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: widget.child,
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
