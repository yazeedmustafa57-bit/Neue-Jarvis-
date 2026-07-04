import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ai_service.dart';
import '../providers/jarvis_provider.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<JarvisProvider>(
      builder: (context, jarvis, _) {
        final statusItems = [
          ('CORE:', 'ONLINE'),
          ('DATABASE:', 'CONNECTED'),
          ('REMINDERS:', 'READY'),
          ('AI:', AiService.hasApiKey ? 'READY' : 'NO KEY'),
          ('VOICE:', jarvis.voiceActive ? 'ACTIVE' : 'OFF'),
          ('UPTIME:', jarvis.uptime),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statusItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 102, 17, 1),
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: item.$1 == 'VOICE:' && jarvis.voiceActive
                          ? const Color.fromRGBO(0, 255, 136, 1)
                          : const Color.fromRGBO(255, 204, 102, 1),
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
