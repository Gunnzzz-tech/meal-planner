import 'package:hive_flutter/hive_flutter.dart';
import '../models/meal_plan.dart';

class HiveService {
  static const String _mealBoxName = 'meals';
  static const String _mealPlanBoxName = 'meal_plans';
  
  static Box<Meal>? _mealBox;
  static Box<MealPlan>? _mealPlanBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(NutritionAdapter());
    Hive.registerAdapter(MealAdapter());
    Hive.registerAdapter(MealPlanAdapter());
    
    // Open boxes
    _mealBox = await Hive.openBox<Meal>(_mealBoxName);
    _mealPlanBox = await Hive.openBox<MealPlan>(_mealPlanBoxName);
    
    print('Hive initialized successfully. Meal box: ${_mealBox?.isOpen}, MealPlan box: ${_mealPlanBox?.isOpen}');
  }

  // Meal operations
  static Future<void> saveMeal(Meal meal) async {
    if (_mealBox == null) {
      print('Error: Meal box is not initialized');
      return;
    }
    await _mealBox!.add(meal);
    print('Meal saved successfully: ${meal.mealName}');
  }

  static List<Meal> getAllMeals() {
    if (_mealBox == null) {
      print('Error: Meal box is not initialized');
      return [];
    }
    final meals = _mealBox!.values.toList();
    print('Retrieved ${meals.length} meals from Hive');
    return meals;
  }

  static List<Meal> getMealsByDate(DateTime date) {
    final allMeals = getAllMeals();
    return allMeals.where((meal) {
      return meal.dateTime.year == date.year &&
             meal.dateTime.month == date.month &&
             meal.dateTime.day == date.day;
    }).toList();
  }

  static Future<void> deleteMeal(Meal meal) async {
    // Find the meal by its properties and delete it
    final meals = _mealBox?.values.toList() ?? [];
    for (int i = 0; i < meals.length; i++) {
      if (meals[i].mealName == meal.mealName && 
          meals[i].dateTime == meal.dateTime &&
          meals[i].type == meal.type) {
        await _mealBox?.deleteAt(i);
        break;
      }
    }
  }

  // Meal plan operations
  static Future<void> saveMealPlan(MealPlan mealPlan) async {
    await _mealPlanBox?.add(mealPlan);
  }

  static List<MealPlan> getAllMealPlans() {
    return _mealPlanBox?.values.toList() ?? [];
  }

  static List<MealPlan> getMealPlansByDate(DateTime date) {
    final allPlans = getAllMealPlans();
    return allPlans.where((plan) {
      return plan.dateTime.year == date.year &&
             plan.dateTime.month == date.month &&
             plan.dateTime.day == date.day;
    }).toList();
  }

  static Future<void> deleteMealPlan(MealPlan mealPlan) async {
    // Find the meal plan by its properties and delete it
    final mealPlans = _mealPlanBox?.values.toList() ?? [];
    for (int i = 0; i < mealPlans.length; i++) {
      if (mealPlans[i].dateTime == mealPlan.dateTime &&
          mealPlans[i].meals.length == mealPlan.meals.length) {
        await _mealPlanBox?.deleteAt(i);
        break;
      }
    }
  }

  // Analytics
  static Map<String, int> getDailyNutritionSummary(DateTime date) {
    final meals = getMealsByDate(date);
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;

    for (final meal in meals) {
      totalCalories += meal.nutrition.calories;
      totalProtein += meal.nutrition.protein;
      totalCarbs += meal.nutrition.carbs;
      totalFat += meal.nutrition.fat;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  static List<Map<String, dynamic>> getWeeklyNutritionTrends() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> trends = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final summary = getDailyNutritionSummary(date);
      trends.add({
        'date': date,
        'calories': summary['calories'] ?? 0,
        'protein': summary['protein'] ?? 0,
        'carbs': summary['carbs'] ?? 0,
        'fat': summary['fat'] ?? 0,
      });
    }

    return trends;
  }

  // Combined analytics (meals + meal plans)
  static Map<String, int> getCombinedDailyNutritionSummary(DateTime date) {
    final mealSummary = getDailyNutritionSummary(date);
    final plans = getMealPlansByDate(date);

    int totalCalories = mealSummary['calories'] ?? 0;
    int totalProtein = mealSummary['protein'] ?? 0;
    int totalCarbs = mealSummary['carbs'] ?? 0;
    int totalFat = mealSummary['fat'] ?? 0;

    for (final plan in plans) {
      totalCalories += plan.totalNutrition.calories;
      totalProtein += plan.totalNutrition.protein;
      totalCarbs += plan.totalNutrition.carbs;
      totalFat += plan.totalNutrition.fat;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  static int getCombinedMealCountForDate(DateTime date) {
    final meals = getMealsByDate(date).length;
    final plans = getMealPlansByDate(date);
    final mealsInPlans = plans.fold<int>(0, (sum, p) => sum + p.meals.length);
    return meals + mealsInPlans;
  }

  static void close() {
    _mealBox?.close();
    _mealPlanBox?.close();
  }
}
