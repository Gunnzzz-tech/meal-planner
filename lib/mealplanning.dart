import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../services/gemini_service.dart';
import '../models/meal_plan.dart';
import '../services/hive_service.dart';
class MealPlanningPage extends StatefulWidget {
  const MealPlanningPage({super.key});

  @override
  State<MealPlanningPage> createState() => _MealPlanningPageState();
}

class _MealPlanningPageState extends State<MealPlanningPage> {
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  List<String> _extraPrefs = [];
  String _diet = "None";
  bool _includeSnacks = true;

  MealPlan? _mealPlan;
  bool _loading = false;
  String? _errorMessage;

  GeminiService? _gemini;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _gemini = GeminiService(apiKey);
    } else {
      _errorMessage = "GEMINI_API_KEY not found in environment variables";
    }
  }

  Future<void> _generateMealPlan() async {
    if (_gemini == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gemini API key not configured")),
      );
      return;
    }

    if (_calorieController.text.isEmpty ||
        _proteinController.text.isEmpty ||
        _carbController.text.isEmpty ||
        _fatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all macros before generating")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Get raw response from Gemini
      final rawResponse = await _gemini!.generateMealPlan(
        calories: int.parse(_calorieController.text),
        protein: int.parse(_proteinController.text),
        carbs: int.parse(_carbController.text),
        fat: int.parse(_fatController.text),
        diet: _diet,
        includeSnacks: _includeSnacks,
      );

      // 2. Extract only JSON portion
      final extracted = _extractJson(rawResponse);
      if (extracted == null) {
        // Try to create a fallback meal plan if JSON parsing fails
        print("Failed to parse JSON, creating fallback meal plan");
        final fallbackPlan = _createFallbackMealPlan();
        setState(() {
          _loading = false;
          _mealPlan = fallbackPlan;
        });
        return;
      }

      // 3. Parse JSON and validate structure
      final jsonData = jsonDecode(extracted);
      if (jsonData is! Map<String, dynamic>) {
        throw Exception("Invalid JSON structure. Expected Map but got ${jsonData.runtimeType}");
      }

      // 4. Parse into model
      final mealPlan = MealPlan.fromJson(jsonData);

      setState(() {
        _loading = false;
        _mealPlan = mealPlan;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = "Error generating meal plan: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _saveMealPlan() async {
    if (_mealPlan == null) return;

    try {
      await HiveService.saveMealPlan(_mealPlan!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan saved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving meal plan: $e")),
      );
    }
  }

  String? _extractJson(String rawText) {
    // Remove code fences and clean up
    String cleaned = rawText
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .replaceAll("```json", "")
        .trim();

    // Find the first "{" and last "}" to slice valid JSON
    int start = cleaned.indexOf("{");
    int end = cleaned.lastIndexOf("}");
    
    if (start != -1 && end != -1 && end > start) {
      String jsonCandidate = cleaned.substring(start, end + 1);
      
      // Try to validate the JSON structure
      try {
        final parsed = jsonDecode(jsonCandidate);
        if (parsed is Map<String, dynamic>) {
          return jsonCandidate;
        }
      } catch (e) {
        // If parsing fails, try to find a better JSON block
        print("JSON parsing failed, trying alternative extraction: $e");
      }
    }
    
    // Alternative: look for JSON-like patterns
    final lines = cleaned.split('\n');
    StringBuffer jsonBuffer = StringBuffer();
    bool inJson = false;
    
    for (String line in lines) {
      if (line.trim().startsWith('{')) {
        inJson = true;
        jsonBuffer.clear();
      }
      if (inJson) {
        jsonBuffer.writeln(line);
        if (line.trim().endsWith('}')) {
          try {
            final candidate = jsonBuffer.toString();
            final parsed = jsonDecode(candidate);
            if (parsed is Map<String, dynamic>) {
              return candidate;
            }
          } catch (e) {
            // Continue looking
          }
        }
      }
    }
    
    return null;
  }

  MealPlan _createFallbackMealPlan() {
    final targetCalories = int.parse(_calorieController.text);
    final targetProtein = int.parse(_proteinController.text);
    final targetCarbs = int.parse(_carbController.text);
    final targetFat = int.parse(_fatController.text);

    final meals = <Meal>[];
    
    // Create breakfast
    final breakfastCalories = (targetCalories * 0.25).round();
    final breakfastProtein = (targetProtein * 0.25).round();
    final breakfastCarbs = (targetCarbs * 0.25).round();
    final breakfastFat = (targetFat * 0.25).round();
    
    meals.add(Meal(
      mealName: "Healthy Breakfast",
      type: "breakfast",
      ingredients: ["Oatmeal", "Banana", "Almonds", "Milk"],
      nutrition: Nutrition(
        calories: breakfastCalories,
        protein: breakfastProtein,
        carbs: breakfastCarbs,
        fat: breakfastFat,
      ),
    ));

    // Create lunch
    final lunchCalories = (targetCalories * 0.35).round();
    final lunchProtein = (targetProtein * 0.35).round();
    final lunchCarbs = (targetCarbs * 0.35).round();
    final lunchFat = (targetFat * 0.35).round();
    
    meals.add(Meal(
      mealName: "Balanced Lunch",
      type: "lunch",
      ingredients: ["Grilled Chicken", "Brown Rice", "Vegetables", "Olive Oil"],
      nutrition: Nutrition(
        calories: lunchCalories,
        protein: lunchProtein,
        carbs: lunchCarbs,
        fat: lunchFat,
      ),
    ));

    // Create dinner
    final dinnerCalories = (targetCalories * 0.35).round();
    final dinnerProtein = (targetProtein * 0.35).round();
    final dinnerCarbs = (targetCarbs * 0.35).round();
    final dinnerFat = (targetFat * 0.35).round();
    
    meals.add(Meal(
      mealName: "Nutritious Dinner",
      type: "dinner",
      ingredients: ["Salmon", "Sweet Potato", "Broccoli", "Quinoa"],
      nutrition: Nutrition(
        calories: dinnerCalories,
        protein: dinnerProtein,
        carbs: dinnerCarbs,
        fat: dinnerFat,
      ),
    ));

    // Add snack if requested
    if (_includeSnacks) {
      final snackCalories = (targetCalories * 0.05).round();
      final snackProtein = (targetProtein * 0.05).round();
      final snackCarbs = (targetCarbs * 0.05).round();
      final snackFat = (targetFat * 0.05).round();
      
      meals.add(Meal(
        mealName: "Healthy Snack",
        type: "snack",
        ingredients: ["Greek Yogurt", "Berries", "Nuts"],
        nutrition: Nutrition(
          calories: snackCalories,
          protein: snackProtein,
          carbs: snackCarbs,
          fat: snackFat,
        ),
      ));
    }

    // Calculate totals
    final totalCalories = meals.fold(0, (sum, meal) => sum + meal.nutrition.calories);
    final totalProtein = meals.fold(0, (sum, meal) => sum + meal.nutrition.protein);
    final totalCarbs = meals.fold(0, (sum, meal) => sum + meal.nutrition.carbs);
    final totalFat = meals.fold(0, (sum, meal) => sum + meal.nutrition.fat);

    return MealPlan(
      meals: meals,
      totalNutrition: Nutrition(
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
      ),
    );
  }

  Widget _buildNutritionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dietary preference
            SizedBox(height:40),
            Card(
              color:Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height:10),

                    // Title
                    Center(
                      child: Text(
                        "Meal Planning Assistant",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dietary preference
                    const Text("Dietary Preference", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _diet,
                      isExpanded: true,
                      items: ["None", "Vegetarian", "Vegan", "Keto"].map((diet) {
                        return DropdownMenuItem(value: diet, child: Text(diet));
                      }).toList(),
                      onChanged: (val) => setState(() => _diet = val!),
                    ),
                    const Divider(height: 24),

                    // Daily Goals
                    const Text("Daily Goals", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _calorieController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Calories",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _proteinController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Protein (g)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _carbController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Carbs (g)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Fat (g)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Extra Preferences
                    const Text("Extra Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildFilterChip("Gluten-Free"),
                        _buildFilterChip("Dairy-Free"),
                        _buildFilterChip("High Fiber"),
                        _buildFilterChip("Low Sugar"),
                        _buildFilterChip("Spicy Food"),
                      ],
                    ),
                    const Divider(height: 24),

                    // Include Snacks
                    SwitchListTile(
                      title: const Text("Include Snacks"),
                      value: _includeSnacks,
                      activeColor: Colors.red.shade200,
                      onChanged: (val) => setState(() => _includeSnacks = val),
                    ),

                    const SizedBox(height: 16),

                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _generateMealPlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text(
                          "Generate AI Meal Plan",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color:Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],

            // Show Meal Plan
            if (_mealPlan != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Generated Meal Plan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _saveMealPlan,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Plan"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade300),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Individual meal items with better display
              ..._mealPlan!.meals.map((meal) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(
                      "${meal.type.toUpperCase()}: ${meal.mealName}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Calories: ${meal.nutrition.calories} | "
                      "Protein: ${meal.nutrition.protein}g | "
                      "Carbs: ${meal.nutrition.carbs}g | "
                      "Fat: ${meal.nutrition.fat}g",
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Ingredients:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: meal.ingredients.map((ingredient) {
                                return Chip(
                                  label: Text(ingredient),
                                  backgroundColor: Colors.green.shade100,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNutritionChip("Calories", "${meal.nutrition.calories}", Colors.red),
                                _buildNutritionChip("Protein", "${meal.nutrition.protein}g", Colors.blue),
                                _buildNutritionChip("Carbs", "${meal.nutrition.carbs}g", Colors.orange),
                                _buildNutritionChip("Fat", "${meal.nutrition.fat}g", Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Daily Nutritional Summary
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Daily Nutritional Summary",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNutritionChip("Total Calories", "${_mealPlan!.totalNutrition.calories}", Colors.red),
                          _buildNutritionChip("Total Protein", "${_mealPlan!.totalNutrition.protein}g", Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNutritionChip("Total Carbs", "${_mealPlan!.totalNutrition.carbs}g", Colors.orange),
                          _buildNutritionChip("Total Fat", "${_mealPlan!.totalNutrition.fat}g", Colors.purple),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
  Widget _buildGeminiResponse(String response) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: MarkdownBody(
          data: response,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            p: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      ),
    );
  }
  Widget _buildFilterChip(String label) {
    final selected = _extraPrefs.contains(label);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        setState(() {
          if (val) {
            if (!_extraPrefs.contains(label)) _extraPrefs.add(label);
          } else {
            _extraPrefs.remove(label);
          }
        });
      },
      selectedColor: Colors.red.shade100,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: true,
      checkmarkColor: Colors.white,
    );
  }


}
