import 'dart:math';
import 'package:flutter/material.dart';

class BrainNode {
  double x, y, z;
  double phase, speed, amp;
  double px, py; // projected 2D

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
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BrainPainter(
        nodes: _nodes,
        connections: _connections,
        time: _controller.value * 60,
      ),
      size: Size.infinite,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _BrainPainter extends CustomPainter {
  final List<BrainNode> nodes;
  final List<List<int>> connections;
  final double time;
  final double rotationY;
  final double rotationX;

  _BrainPainter({
    required this.nodes,
    required this.connections,
    required this.time,
  }) : rotationY = time * 0.25,
       rotationX = 3.0 * sin(time * 0.06);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide * 0.35;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final cosR = cos(rotationY * pi / 180);
    final sinR = sin(rotationY * pi / 180);
    final cosX = cos(rotationX * pi / 180);
    final sinX = sin(rotationX * pi / 180);

    // Project nodes to 2D
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final t = time;

      // Organic breathing
      final ax = n.amp * sin(t * 0.5 * n.speed + n.phase);
      final ay = n.amp * sin(t * 0.7 * n.speed + n.phase * 1.3);
      final az = n.amp * sin(t * 0.6 * n.speed + n.phase * 0.9);

      var x = n.x + ax;
      var y = n.y + ay;
      var z = n.z + az;

      // Rotate Y
      var rx = x * cosR - z * sinR;
      var rz = x * sinR + z * cosR;
      x = rx;
      z = rz;

      // Rotate X
      var ry = y * cosX - z * sinX;
      var rz2 = y * sinX + z * cosX;
      y = ry;
      z = rz2;

      n.px = cx + x * scale;
      n.py = cy - y * scale;
    }

    // Sort nodes by Z for depth
    final sortedIndices = List.generate(nodes.length, (i) => i);
    sortedIndices.sort((a, b) => nodes[a].z.compareTo(nodes[b].z));

    // Draw connections
    for (final pair in connections) {
      final i = pair[0];
      final j = pair[1];
      final n1 = nodes[i];
      final n2 = nodes[j];

      final dx = n1.x - n2.x;
      final dy = n1.y - n2.y;
      final dz = n1.z - n2.z;
      final dist = sqrt(dx * dx + dy * dy + dz * dz);

      var alpha = (1.0 - dist / _connectionDist).clamp(0.0, 1.0);
      final pulse = 0.5 + 0.5 * sin(time * 1.5 + n1.phase + n2.phase);
      alpha *= (0.3 + 0.7 * pulse);

      if (alpha < 0.05) continue;

      final paint = Paint()
        ..color = Color.fromRGBO(255, 120 + (60 * pulse).toInt(), 20, alpha * 0.4)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(n1.px, n1.py), Offset(n2.px, n2.py), paint);
    }

    // Draw nodes
    for (final i in sortedIndices) {
      final n = nodes[i];
      final pulse = 0.6 + 0.4 * sin(time * 2.0 + n.phase);

      // Glow
      /*final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 140, 30, pulse * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(n.px, n.py), 6.0, glowPaint);*/

      // Core
      final corePaint = Paint()
        ..color = Color.fromRGBO(
          220 + (35 * pulse).toInt(),
          120 + (80 * pulse).toInt(),
          20,
          0.6 + 0.4 * pulse,
        );
      canvas.drawCircle(Offset(n.px, n.py), 1.5 + 1.0 * pulse, corePaint);
    }
  }

  @override
  bool shouldRepaint(_BrainPainter oldDelegate) => true;
}
