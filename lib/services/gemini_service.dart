import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/secrets.dart';

class GeminiService {
  // Go to lib/config/secrets.dart put the api there
  static const String _apiKey = '$geminiApiKey';

  static Future<Map<String, dynamic>> analyzeImages(List<File> imageFiles) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );

    // Build parts: prompt + all images
    final parts = <Part>[];

    const prompt = '''
Analyze these photos of the same found item (front, back, other angles).
Use ALL images together and respond ONLY with valid JSON:
{
  "object_type": "water bottle",
  "color": "blue",
  "brand": "Milton"
}
If you are not sure about a field, return an empty string for that field.
''';

    parts.add(TextPart(prompt));

    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      parts.add(DataPart('image/jpeg', bytes));
    }

    final response = await model.generateContent([
      Content.multi(parts),
    ]);

    final text = response.text ?? '{}';
    print('Gemini raw response: $text');

    String extract(String key) {
      final reg = RegExp('"$key"\\s*:\\s*"([^"]*)"');
      final match = reg.firstMatch(text);
      return match?.group(1) ?? '';
    }

    return {
      'object_type': extract('object_type'),
      'color': extract('color'),
      'brand': extract('brand'),
    };
  }
}
