import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ─── Brain Node (mutable fields for perf) ─────────────────────────────
class BrainNode {
  double x = 0, y = 0, z = 0;
  double phase = 0, speed = 0, amp = 0;
  double px = 0, py = 0;

  BrainNode(Random rng) {
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

// ─── Optimized Brain Hologram Widget ──────────────────────────────────
class BrainHologram extends StatefulWidget {
  const BrainHologram({super.key});

  @override
  State<BrainHologram> createState() => _BrainHologramState();
}

class _BrainHologramState extends State<BrainHologram>
    with SingleTickerProviderStateMixin {
  static const int _numNodes = 2800;
  static const double _connectionDist = 0.40;

  late List<BrainNode> _nodes;
  late Int32List _connections; // flat int pairs: [i1, j1, i2, j2, ...]
  late int _connectionCount;
  late AnimationController _controller;

  // Pre-allocated projected coordinate buffer
  final Float64List _projBuffer = Float64List(_numNodes * 2);
  final Float32List _rawPoints = Float32List(_numNodes * 2);

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _nodes = List.generate(_numNodes, (_) => BrainNode(rng));
    _computeConnections();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _controller.addListener(() => setState(() {}));
  }

  void _computeConnections() {
    // First pass: count connections
    int count = 0;
    for (int i = 0; i < _numNodes; i++) {
      final xi = _nodes[i].x, yi = _nodes[i].y, zi = _nodes[i].z;
      for (int j = i + 1; j < _numNodes; j++) {
        final dx = xi - _nodes[j].x;
        final dy = yi - _nodes[j].y;
        final dz = zi - _nodes[j].z;
        if (dx * dx + dy * dy + dz * dz < _connectionDist * _connectionDist) {
          count++;
        }
      }
    }
    // Second pass: fill flat Int32List
    _connections = Int32List(count * 2);
    int idx = 0;
    for (int i = 0; i < _numNodes; i++) {
      final xi = _nodes[i].x, yi = _nodes[i].y, zi = _nodes[i].z;
      for (int j = i + 1; j < _numNodes; j++) {
        final dx = xi - _nodes[j].x;
        final dy = yi - _nodes[j].y;
        final dz = zi - _nodes[j].z;
        if (dx * dx + dy * dy + dz * dz < _connectionDist * _connectionDist) {
          _connections[idx++] = i;
          _connections[idx++] = j;
        }
      }
    }
    _connectionCount = count;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Copy projected coords into Float32List for drawRawPoints
    for (int i = 0; i < _numNodes; i++) {
      _rawPoints[i * 2] = _projBuffer[i * 2];
      _rawPoints[i * 2 + 1] = _projBuffer[i * 2 + 1];
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _BrainPainter(
          nodes: _nodes,
          connections: _connections,
          connectionCount: _connectionCount,
          projBuffer: _projBuffer,
          rawPoints: _rawPoints,
          time: DateTime.now().millisecondsSinceEpoch / 1000,
        ),
        size: Size.infinite,
      ),
    );
  }
}

// ─── Optimized Painter ────────────────────────────────────────────────
class _BrainPainter extends CustomPainter {
  final List<BrainNode> nodes;
  final Int32List connections;
  final int connectionCount;
  final Float64List projBuffer;
  final Float32List rawPoints;
  final double time;

  _BrainPainter({
    required this.nodes,
    required this.connections,
    required this.connectionCount,
    required this.projBuffer,
    required this.rawPoints,
    required this.time,
  });

  // ── Static pre-allocated paints ────────────────────────────────────
  static final Paint _bgPaint = Paint();
  static final Paint _connPaint = Paint()..strokeWidth = 0.6;
  static final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final Paint _corePaint = Paint();
  static final Paint _centerPaint = Paint();

  // Cached shaders (rebuilt only when size changes)
  static Size _cachedSize = Size.zero;
  static Shader? _bgShader;
  static Shader? _centerShader;

  static void _ensureShaders(Size size) {
    if (_cachedSize == size && _bgShader != null) return;
    _cachedSize = size;
    final cx = size.width / 2, cy = size.height / 2;
    _bgShader = RadialGradient(
      colors: const [
        Color.fromRGBO(20, 5, 0, 1),
        Color.fromRGBO(8, 2, 12, 1),
        Color.fromRGBO(8, 2, 12, 1),
      ],
      radius: 0.9,
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.5));

    _centerShader = RadialGradient(
      colors: [
        const Color.fromRGBO(255, 100, 20, 40),
        const Color.fromRGBO(255, 80, 10, 10),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = size.shortestSide * 0.38;
    final rotation = time * 0.08;
    final cosR = cos(rotation);
    final sinR = sin(rotation);
    final maxScreenDist = size.shortestSide * 0.35;
    final maxScreenDistSq = maxScreenDist * maxScreenDist;

    // ── Step 1: Project nodes ──────────────────────────────────────
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final x1 = n.x * cosR - n.z * sinR;
      final z1 = n.x * sinR + n.z * cosR;
      final bob = sin(time * n.speed + n.phase) * n.amp;
      final y2 = n.y + bob;
      final persp = 3.0 / (3.0 + z1);
      n.px = centerX + x1 * scale * persp;
      n.py = centerY - y2 * scale * persp;
      projBuffer[i * 2] = n.px;
      projBuffer[i * 2 + 1] = n.py;
    }

    // ── Step 2: Background (cached shader) ────────────────────────
    _ensureShaders(size);
    _bgPaint.shader = _bgShader;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // ── Step 3: Connections (batched) ──────────────────────────────
    for (int i = 0; i < connectionCount; i++) {
      final i1 = connections[i * 2];
      final i2 = connections[i * 2 + 1];
      final dx = projBuffer[i1 * 2] - projBuffer[i2 * 2];
      final dy = projBuffer[i1 * 2 + 1] - projBuffer[i2 * 2 + 1];
      final distSq = dx * dx + dy * dy;
      if (distSq < maxScreenDistSq) {
        final alpha = ((1.0 - sqrt(distSq) / maxScreenDist) * 100)
            .toInt()
            .clamp(20, 100);
        _connPaint.color = Color.fromARGB(alpha, 255, 120, 30);
        canvas.drawLine(
          Offset(projBuffer[i1 * 2], projBuffer[i1 * 2 + 1]),
          Offset(projBuffer[i2 * 2], projBuffer[i2 * 2 + 1]),
          _connPaint,
        );
      }
    }

    // ── Step 4: Core points (batch via drawRawPoints) ────────────
    _corePaint.color = const Color.fromRGBO(255, 170, 50, 200);
    canvas.drawRawPoints(ui.PointMode.points, rawPoints, _corePaint);

    // ── Step 5: Glow for closer nodes ─────────────────────────────
    _glowPaint.color = const Color.fromRGBO(255, 140, 30, 40);
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final depth = (1.0 - (n.z + 2.0) / 4.0).clamp(0.0, 1.0);
      if (depth > 0.35) {
        canvas.drawCircle(
          Offset(n.px, n.py),
          1.2 + depth * 3.0,
          _glowPaint,
        );
      }
    }

    // ── Step 6: Center glow overlay ──────────────────────────────
    _centerPaint.shader = _centerShader;
    canvas.drawRect(Offset.zero & size, _centerPaint);
  }

  @override
  bool shouldRepaint(_BrainPainter oldDelegate) => true;
}
