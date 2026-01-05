import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // TODO: REPLACE this with your real API key from aistudio.google.com
  static const String _apiKey = 'AIzaSyAjfaMjG7OAoMXHMB3GO464ll0dX_j5ahs';

  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );

    final bytes = await imageFile.readAsBytes();

    const prompt = '''
Analyze this image of a found item and return ONLY a JSON object like:
{
  "object_type": "water bottle",
  "color": "blue",
  "brand": "Milton"
}
''';

    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', bytes),
      ]),
    ]);

    final text = response.text ?? '{}';
    print('Gemini raw response: $text');

    // Very simple parsing: try to extract values with regex
    final result = <String, dynamic>{};

    String extract(String key) {
      final reg = RegExp('"$key"\\s*:\\s*"([^"]*)"');
      final match = reg.firstMatch(text);
      return match?.group(1) ?? '';
    }

    result['object_type'] = extract('object_type');
    result['color'] = extract('color');
    result['brand'] = extract('brand');

    return result;
  }
}
