import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final String? _apiKey = dotenv.env['OPENAI_API_KEY'];
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static bool get hasApiKey =>
      _apiKey != null && _apiKey!.isNotEmpty && _apiKey != 'sk-dein-openai-api-key-hier';

  static Future<String> askAi(String prompt) async {
    if (!hasApiKey) {
      throw Exception(
          'OPENAI_API_KEY ist nicht gesetzt.\nFüge ihn in .env ein:\n  OPENAI_API_KEY=sk-...');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Du bist JARVIS, ein futuristischer KI-Assistent im Stil von Iron Man. Antworte auf Deutsch, präzise und technisch. Du hilfst bei Aufgaben, Analysen und Automation.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 512,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] as String? ?? '';
        return reply;
      } else if (response.statusCode == 429) {
        return 'Fehler: API-Kontingent erschöpft. Bitte überprüfe deinen OpenAI-Plan.';
      } else {
        final error = jsonDecode(response.body);
        final msg = error['error']['message'] ?? 'Unbekannter Fehler';
        return 'Fehler bei der KI-Anfrage: $msg';
      }
    } catch (e) {
      return 'Fehler bei der KI-Anfrage: $e';
    }
  }
}
