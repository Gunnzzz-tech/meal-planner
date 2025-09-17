import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mime/mime.dart'; // for mime type detection
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../models/meal_plan.dart';
import '../../../services/hive_service.dart';

class FoodService {
  late final GenerativeModel model;

  FoodService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("❌ Missing GEMINI_API_KEY in .env file");
    }
    model = GenerativeModel(
      model: "gemini-1.5-flash",
      apiKey: apiKey,
    );
  }

  Future<String> analyzeFood(File imageFile) async {
    try {
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final bytes = await imageFile.readAsBytes();

      final response = await model.generateContent([
        Content.multi([
          TextPart("""
Analyze this food image and provide a detailed analysis. Include:
1. Meal name and description
2. Estimated calories
3. Macronutrients (protein, carbs, fat in grams)
4. Key ingredients
5. Any dietary considerations

Format your response as a clear, readable analysis with bullet points.
"""),
          DataPart(mimeType, bytes),
        ])
      ]);

      final analysis = response.text ?? "No response from Gemini.";
      
      // Try to parse and save as structured meal data
      await _parseAndSaveMeal(analysis);
      
      return analysis;
    } catch (e) {
      return "Error analyzing food: $e";
    }
  }

  Future<void> _parseAndSaveMeal(String analysis) async {
    try {
      // Extract basic information from the analysis text
      final lines = analysis.split('\n');
      String mealName = 'Analyzed Meal';
      int calories = 0;
      int protein = 0;
      int carbs = 0;
      int fat = 0;
      List<String> ingredients = [];

      // Simple parsing logic - look for common patterns
      for (String line in lines) {
        final lowerLine = line.toLowerCase();
        
        // Extract meal name (usually the first descriptive line)
        if (line.contains(':') && !line.contains('calories') && !line.contains('protein') && 
            !line.contains('carbs') && !line.contains('fat') && mealName == 'Analyzed Meal') {
          mealName = line.split(':').first.trim();
        }
        
        // Extract calories
        if (lowerLine.contains('calories') || lowerLine.contains('cal')) {
          final regex = RegExp(r'(\d+)');
          final match = regex.firstMatch(line);
          if (match != null) {
            calories = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }
        
        // Extract protein
        if (lowerLine.contains('protein')) {
          final regex = RegExp(r'(\d+)');
          final match = regex.firstMatch(line);
          if (match != null) {
            protein = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }
        
        // Extract carbs
        if (lowerLine.contains('carb') || lowerLine.contains('carbohydrate')) {
          final regex = RegExp(r'(\d+)');
          final match = regex.firstMatch(line);
          if (match != null) {
            carbs = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }
        
        // Extract fat
        if (lowerLine.contains('fat')) {
          final regex = RegExp(r'(\d+)');
          final match = regex.firstMatch(line);
          if (match != null) {
            fat = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }
        
        // Extract ingredients (look for bullet points or lists)
        if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
          final ingredient = line.replaceAll(RegExp(r'^[•\-*]\s*'), '').trim();
          if (ingredient.isNotEmpty && !ingredient.toLowerCase().contains('calories')) {
            ingredients.add(ingredient);
          }
        }
      }

      // If no specific nutrition data found, estimate based on meal type
      if (calories == 0) {
        calories = _estimateCalories(mealName, ingredients);
      }
      if (protein == 0) {
        protein = (calories * 0.15 / 4).round(); // 15% of calories from protein
      }
      if (carbs == 0) {
        carbs = (calories * 0.55 / 4).round(); // 55% of calories from carbs
      }
      if (fat == 0) {
        fat = (calories * 0.30 / 9).round(); // 30% of calories from fat
      }

      // Create meal object
      final nutrition = Nutrition(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

      final meal = Meal(
        mealName: mealName,
        type: 'analyzed',
        ingredients: ingredients.isNotEmpty ? ingredients : ['Various ingredients'],
        nutrition: nutrition,
      );

      // Save to Hive
      await HiveService.saveMeal(meal);
      print('Successfully saved meal to Hive: ${meal.mealName}');
    } catch (e) {
      print('Error parsing meal data: $e');
      // Don't throw error, just log it - the text analysis is still useful
    }
  }

  int _estimateCalories(String mealName, List<String> ingredients) {
    final lowerName = mealName.toLowerCase();
    
    // Basic calorie estimation based on meal type
    if (lowerName.contains('breakfast') || lowerName.contains('cereal') || lowerName.contains('toast')) {
      return 300;
    } else if (lowerName.contains('lunch') || lowerName.contains('sandwich') || lowerName.contains('salad')) {
      return 500;
    } else if (lowerName.contains('dinner') || lowerName.contains('pasta') || lowerName.contains('rice')) {
      return 600;
    } else if (lowerName.contains('snack') || lowerName.contains('fruit')) {
      return 150;
    } else {
      return 400; // Default estimate
    }
  }
}

class LocalFoodStorage {
  static const String _keyLastAnalysis = 'last_food_analysis';

  Future<void> saveLastAnalysis(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastAnalysis, text);
  }

  Future<String?> getLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastAnalysis);
  }
}
