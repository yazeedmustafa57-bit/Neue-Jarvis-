import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jarvis_provider.dart';

class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<JarvisProvider>(
      builder: (context, jarvis, _) {
        final active = jarvis.voiceActive;
        final state = jarvis.voiceService.state;

        String label;
        Color color;
        IconData icon;

        if (active) {
          label = '🔴  DEAKTIVIEREN';
          color = const Color.fromRGBO(0, 255, 100, 1);
          icon = Icons.mic;
        } else {
          label = '🎤  AKTIVIEREN';
          color = const Color.fromRGBO(255, 140, 30, 1);
          icon = Icons.mic_none;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active ? '🎤 Höre zu …' : '🎤 Mikrofon',
              style: TextStyle(
                color: active
                    ? const Color.fromRGBO(0, 255, 136, 1)
                    : const Color.fromRGBO(255, 204, 102, 1),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => jarvis.toggleVoice(),
              icon: Icon(icon, color: color, size: 20),
              label: Text(
                label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: active
                    ? const Color.fromRGBO(0, 255, 100, 30)
                    : const Color.fromRGBO(255, 120, 20, 30),
                side: BorderSide(
                  color: active
                      ? const Color.fromRGBO(0, 255, 100, 120)
                      : const Color.fromRGBO(255, 120, 20, 120),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Befehle: YouTube · Google ·\nChrome · Discord · Beenden',
              style: TextStyle(
                color: const Color.fromRGBO(255, 136, 51, 1),
                fontSize: 10,
                fontFamily: 'Courier',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}
