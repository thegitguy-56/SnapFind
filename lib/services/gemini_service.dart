import 'dart:convert'; // Import for jsonDecode
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/secrets.dart';

class GeminiService {
  static Future<Map<String, dynamic>> analyzeImages(
    List<File> imageFiles,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: Secrets.geminiApiKey,
    );

    final parts = <Part>[];

    // UPDATED PROMPT
    const prompt = '''
Analyze these photos of the same found item. 
1. Identify the MAIN object. If the object is inside a case or cover (like a phone in a case), identify the object itself (e.g., "smartphone"), not the accessory.
2. Return ONLY a raw JSON object string without markdown code blocks (```json).
3. Follow this exact structure:
{
  "object_type": "Generic name of the item (e.g. smartphone, water bottle, keys)",
  "color": "Dominant color of the item",
  "brand": "Brand name if clearly visible, otherwise empty string"
}
''';

    parts.add(TextPart(prompt));

    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      parts.add(DataPart('image/jpeg', bytes));
    }

    final response = await model.generateContent([Content.multi(parts)]);

    final text = response.text ?? '{}';
    print('Gemini raw response: $text');

    // Robust Parsing using jsonDecode
    // This handles spacing, newlines, and escaping better than regex
    try {
      // Clean up markdown if the model ignores the "no markdown" rule
      final cleanText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final Map<String, dynamic> jsonResponse = jsonDecode(cleanText);

      return {
        'object_type': jsonResponse['object_type']?.toString() ?? '',
        'color': jsonResponse['color']?.toString() ?? '',
        'brand': jsonResponse['brand']?.toString() ?? '',
      };
    } catch (e) {
      print('Error parsing Gemini response: $e');
      return {'object_type': '', 'color': '', 'brand': ''};
    }
  }
}
