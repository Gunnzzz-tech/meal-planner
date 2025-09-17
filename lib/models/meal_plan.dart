import 'package:hive/hive.dart';

part 'meal_plan.g.dart';

@HiveType(typeId: 0)
class Nutrition extends HiveObject {
  @HiveField(0)
  final int calories;
  @HiveField(1)
  final int protein;
  @HiveField(2)
  final int carbs;
  @HiveField(3)
  final int fat;

  Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

@HiveType(typeId: 1)
class Meal extends HiveObject {
  @HiveField(0)
  final String mealName;
  @HiveField(1)
  final String type;
  @HiveField(2)
  final List<String> ingredients;
  @HiveField(3)
  final Nutrition nutrition;
  @HiveField(4)
  final DateTime dateTime;

  Meal({
    required this.mealName,
    required this.type,
    required this.ingredients,
    required this.nutrition,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      mealName: json['mealName'] ?? '',
      type: json['type'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      nutrition: Nutrition.fromJson(json['nutrition'] ?? {}),
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealName': mealName,
      'type': type,
      'ingredients': ingredients,
      'nutrition': nutrition.toJson(),
      'dateTime': dateTime.toIso8601String(),
    };
  }
}

@HiveType(typeId: 2)
class MealPlan extends HiveObject {
  @HiveField(0)
  final List<Meal> meals;
  @HiveField(1)
  final Nutrition totalNutrition;
  @HiveField(2)
  final DateTime dateTime;

  MealPlan({
    required this.meals,
    required this.totalNutrition,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      meals: (json['meals'] as List<dynamic>?)
          ?.map((e) => Meal.fromJson(e))
          .toList() ?? [],
      totalNutrition: Nutrition.fromJson(json['totalNutrition'] ?? {}),
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meals': meals.map((e) => e.toJson()).toList(),
      'totalNutrition': totalNutrition.toJson(),
      'dateTime': dateTime.toIso8601String(),
    };
  }
}
