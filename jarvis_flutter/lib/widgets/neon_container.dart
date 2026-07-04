import 'package:flutter/material.dart';

class NeonContainer extends StatefulWidget {
  final Widget child;
  final String? title;
  final double? width;
  final double? height;

  const NeonContainer({
    super.key,
    required this.child,
    this.title,
    this.width,
    this.height,
  });

  @override
  State<NeonContainer> createState() => _NeonContainerState();
}

class _NeonContainerState extends State<NeonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final opacity = _pulseAnimation.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(
              color: Color.fromRGBO(255, 120, 20, (80 * opacity).toInt()),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4.0),
            color: const Color.fromRGBO(0, 0, 0, 160),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.title != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 120, 20, 30),
                    border: Border(
                      bottom: BorderSide(
                        color: Color.fromRGBO(
                            255, 120, 20, (60 * opacity).toInt()),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      color: Color.fromRGBO(255, 140, 30, (200 * opacity).toInt()),
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: widget.child,
              )),
            ],
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
