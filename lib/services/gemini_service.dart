import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mime/mime.dart' as mime;
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;


class GeminiService {
  final String apiKey;
  GenerativeModel? _model; // lazy load

  GeminiService(this.apiKey);

  GenerativeModel _ensureModel() {
    if (apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
    return _model!;
  }

  // ============ IMAGE ANALYSIS ============
  Future<String> analyzeFood(File imageFile, {String? mimeType}) async {
    try {
      return await _analyzeWithSdk(imageFile, mimeType: mimeType);
    } catch (_) {
      // fallback to REST
    }
    return _analyzeWithRest(imageFile, mimeType: mimeType);
  }

  Future<String> _analyzeWithSdk(File imageFile, {String? mimeType}) async {
    final Uint8List originalBytes = await imageFile.readAsBytes();
    final String detectedMime =
        mimeType ?? mime.lookupMimeType(imageFile.path) ?? 'image/jpeg';

    Uint8List bytesToSend = originalBytes;
    String finalMime = detectedMime;

    if (_requiresConversion(detectedMime)) {
      final decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        final jpeg = img.encodeJpg(decoded, quality: 90);
        bytesToSend = Uint8List.fromList(jpeg);
        finalMime = 'image/jpeg';
      }
    }

    return analyzeFoodBytes(bytesToSend, mimeType: finalMime);
  }

  bool _requiresConversion(String mimeType) {
    final lower = mimeType.toLowerCase();
    return lower.contains('heic') ||
        lower.contains('heif') ||
        lower == 'application/octet-stream';
  }

  Future<String> analyzeFoodBytes(Uint8List bytes,
      {String mimeType = 'image/jpeg'}) async {
    const prompt =
        'Analyze this food image and provide a concise meal description, estimated calories, macronutrients, and any dietary considerations. Format as bullet points.';

    try {
      final model = _ensureModel();
      final content = Content.multi([
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ]);
      final response = await model.generateContent([content]);
      return response.text ?? 'No description available from Gemini.';
    } catch (e) {
      throw Exception('SDK image path failed: $e');
    }
  }

  Future<String> _analyzeWithRest(File imageFile, {String? mimeType}) async {
    final bytes = await imageFile.readAsBytes();
    final String detectedMime =
        mimeType ?? mime.lookupMimeType(imageFile.path) ?? 'image/jpeg';

    Uint8List bytesToSend = bytes;
    String finalMime = detectedMime;

    if (_requiresConversion(detectedMime)) {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final jpeg = img.encodeJpg(decoded, quality: 90);
        bytesToSend = Uint8List.fromList(jpeg);
        finalMime = 'image/jpeg';
      }
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {
              'text':
              'Analyze this food image and provide a concise meal description, estimated calories, macronutrients, and any dietary considerations. Format as bullet points.'
            },
            {
              'inline_data': {
                'mime_type': finalMime,
                'data': base64Encode(bytesToSend),
              }
            }
          ]
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } catch (_) {
        return 'Gemini returned unexpected format (REST):\n${response.body}';
      }
    } else {
      return 'Gemini API error (REST): ${response.statusCode} ${response.body}';
    }
  }

  // ============ TEXT ANALYSIS ============
  Future<String> analyzeText(String text) async {
    try {
      final model = _ensureModel();
      final response = await model.generateContent([
        Content.text(text),
      ]);
      return response.text ?? 'No response text from Gemini.';
    } catch (e) {
      return 'Gemini error (text): $e';
    }
  }
}

// ============ MEAL PLANNING (extension) ============
extension GeminiMealPlanning on GeminiService {
  Future<String> generateMealPlan({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required String diet,
    bool includeSnacks = true,
  }) async {
    final model = _ensureModel();

    final prompt = """
Generate a daily meal plan with the following requirements:
- Calories: $calories
- Protein: $protein g
- Carbs: $carbs g
- Fat: $fat g
- Diet: $diet
- Include snacks: $includeSnacks

IMPORTANT: Return ONLY valid JSON, no additional text or explanations. The JSON must be structured exactly as follows:

{
  "meals": [
    {
      "mealName": "string",
      "type": "breakfast",
      "ingredients": ["ingredient1", "ingredient2"],
      "nutrition": {
        "calories": 400,
        "protein": 20,
        "carbs": 50,
        "fat": 15
      }
    },
    {
      "mealName": "string",
      "type": "lunch",
      "ingredients": ["ingredient1", "ingredient2"],
      "nutrition": {
        "calories": 500,
        "protein": 25,
        "carbs": 60,
        "fat": 18
      }
    },
    {
      "mealName": "string",
      "type": "dinner",
      "ingredients": ["ingredient1", "ingredient2"],
      "nutrition": {
        "calories": 600,
        "protein": 30,
        "carbs": 70,
        "fat": 20
      }
    }
  ],
  "totalNutrition": {
    "calories": 1500,
    "protein": 75,
    "carbs": 180,
    "fat": 53
  }
}

Make sure the totalNutrition values match the sum of all individual meal nutrition values.
""";

    try {
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      return response.text ?? 'No response from Gemini';
    } catch (e) {
      print("Gemini error in generateMealPlan: $e");
      return 'Error generating meal plan: $e';
    }
  }
  
}
