import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/jarvis_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env for OpenAI API key
  await dotenv.load(fileName: '.env');

  // Fullscreen immersive mode for tablet
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) {
    if (systemOverlaysAreVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  });

  // Lock orientation to landscape for the best hologram experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => JarvisProvider()..initialize(),
      child: const JarvisApp(),
    ),
  );
}
