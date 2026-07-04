import 'dart:math';
import 'package:flutter/material.dart';

class BrainNode {
  double x = 0, y = 0, z = 0;
  double phase = 0, speed = 0, amp = 0;
  double px = 0, py = 0; // projected 2D

  BrainNode(Random rng) {
    // Anatomisch inspirierte Gehirnform (2 Hemisphären)
    final region = rng.nextDouble();
    double rx, ry, rz, cx, cy, cz, sf;

    if (region < 0.28) {
      rx = 1.9; ry = 1.5; rz = 1.6;
      cx = -0.5; cy = 0.15; cz = 0.0;
      sf = 0.25 + rng.nextDouble() * 0.75;
    } else if (region < 0.56) {
      rx = 1.9; ry = 1.5; rz = 1.6;
      cx = 0.5; cy = 0.15; cz = 0.0;
      sf = 0.25 + rng.nextDouble() * 0.75;
    } else if (region < 0.72) {
      rx = 1.3; ry = 1.1; rz = 1.3;
      cx = 0.0; cy = 0.05; cz = 0.0;
      sf = 0.1 + rng.nextDouble() * 0.6;
    } else if (region < 0.84) {
      rx = 0.6; ry = 1.3; rz = 0.8;
      cx = 0.0; cy = -1.4; cz = 0.2;
      sf = 0.1 + rng.nextDouble() * 0.8;
    } else {
      rx = 1.1; ry = 0.7; rz = 1.0;
      cx = 0.0; cy = -0.6; cz = -1.6;
      sf = 0.2 + rng.nextDouble() * 0.7;
    }

    final theta = rng.nextDouble() * pi;
    final phi = rng.nextDouble() * 2 * pi;

    x = cx + rx * sf * sin(theta) * cos(phi);
    y = cy + ry * sf * cos(theta);
    z = cz + rz * sf * sin(theta) * sin(phi);

    phase = rng.nextDouble() * 2 * pi;
    speed = 0.4 + rng.nextDouble() * 0.6;
    amp = 0.008 + rng.nextDouble() * 0.017;
  }
}

class BrainHologram extends StatefulWidget {
  const BrainHologram({super.key});

  @override
  State<BrainHologram> createState() => _BrainHologramState();
}

class _BrainHologramState extends State<BrainHologram>
    with SingleTickerProviderStateMixin {
  static const int _numNodes = 3200;
  static const double _connectionDist = 0.40;

  late List<BrainNode> _nodes;
  late List<List<int>> _connections;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _nodes = List.generate(_numNodes, (_) => BrainNode(rng));
    _connections = _computeConnections();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _controller.addListener(() => setState(() {}));
  }

  List<List<int>> _computeConnections() {
    final pairs = <List<int>>[];
    for (int i = 0; i < _numNodes; i++) {
      for (int j = i + 1; j < _numNodes; j++) {
        final dx = _nodes[i].x - _nodes[j].x;
        final dy = _nodes[i].y - _nodes[j].y;
        final dz = _nodes[i].z - _nodes[j].z;
        final dist = sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < _connectionDist) {
          pairs.add([i, j]);
        }
      }
    }
    return pairs;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BrainPainter(
        nodes: _nodes,
        connections: _connections,
        time: DateTime.now().millisecondsSinceEpoch / 1000,
      ),
      size: Size.infinite,
    );
  }
}

class _BrainPainter extends CustomPainter {
  final List<BrainNode> nodes;
  final List<List<int>> connections;
  final double time;

  _BrainPainter({
    required this.nodes,
    required this.connections,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = size.shortestSide * 0.38;
    final rotation = time * 0.08;

    final cosR = cos(rotation);
    final sinR = sin(rotation);

    // Project nodes
    for (final node in nodes) {
      // Apply rotation (Y-axis)
      final x1 = node.x * cosR - node.z * sinR;
      final z1 = node.x * sinR + node.z * cosR;
      final y1 = node.y;

      // Apply slow bob
      final bob = sin(time * node.speed + node.phase) * node.amp;
      final x2 = x1;
      final y2 = y1 + bob;
      final z2 = z1;

      // Perspective projection
      final perspective = 3.0 / (3.0 + z2);
      node.px = centerX + x2 * scale * perspective;
      node.py = centerY - y2 * scale * perspective;
    }

    // Darkness gradient background
    final bgPaint = Paint()..shader = RadialGradient(
      colors: const [
        Color.fromRGBO(20, 5, 0, 1),
        Color.fromRGBO(8, 2, 12, 1),
        Color.fromRGBO(8, 2, 12, 1),
      ],
      radius: 0.9,
    ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: size.width * 0.5));
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw connections
    for (final pair in connections) {
      final n1 = nodes[pair[0]];
      final n2 = nodes[pair[1]];
      final dx = n1.px - n2.px;
      final dy = n1.py - n2.py;
      final screenDist = sqrt(dx * dx + dy * dy);

      if (screenDist < size.shortestSide * 0.35) {
        final alpha = ((1.0 - screenDist / (size.shortestSide * 0.35)) * 120).toInt().clamp(10, 120);
        final paint = Paint()
          ..color = Color.fromARGB(alpha, 255, 120, 30)
          ..strokeWidth = 0.6;
        canvas.drawLine(Offset(n1.px, n1.py), Offset(n2.px, n2.py), paint);
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final z = node.z;
      final depth = (1.0 - (z + 2.0) / 4.0).clamp(0.0, 1.0);
      final baseRadius = 1.2 + depth * 2.0;
      final glowRadius = baseRadius * 3.0;
      final alpha = (80 + (depth * 175).toInt()).clamp(30, 255);
      final glowAlpha = (alpha * 0.3).toInt();

      // Glow
      final glowPaint = Paint()
        ..color = Color.fromARGB(glowAlpha, 255, 140, 30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(node.px, node.py), glowRadius, glowPaint);

      // Core
      final corePaint = Paint()
        ..color = Color.fromARGB(alpha, 255, 170, 50);
      canvas.drawCircle(Offset(node.px, node.py), baseRadius, corePaint);
    }

    // Central glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color.fromRGBO(255, 100, 20, 40),
          const Color.fromRGBO(255, 80, 10, 10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: size.width * 0.3));
    canvas.drawRect(Offset.zero & size, centerGlow);
  }

  @override
  bool shouldRepaint(_BrainPainter oldDelegate) => true;
}
