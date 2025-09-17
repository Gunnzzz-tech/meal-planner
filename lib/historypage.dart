import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/meal_plan.dart';
import '../services/hive_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Meal> _mealHistory = [];
  List<MealPlan> _mealPlans = [];
  List<Map<String, dynamic>> _weeklyTrends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final meals = HiveService.getAllMeals();
      final mealPlans = HiveService.getAllMealPlans();
      final trends = HiveService.getWeeklyNutritionTrends();

      print('Loaded ${meals.length} meals and ${mealPlans.length} meal plans from Hive');

      setState(() {
        _mealHistory = meals;
        _mealPlans = mealPlans;
        _weeklyTrends = trends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    try {
      await HiveService.deleteMeal(meal);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting meal: $e")),
      );
    }
  }

  Future<void> _deleteMealPlan(MealPlan mealPlan) async {
    try {
      await HiveService.deleteMealPlan(mealPlan);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal plan deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting meal plan: $e")),
      );
    }
  }

  Future<void> _createTestMeal() async {
    try {
      final testMeal = Meal(
        mealName: "Test Meal ${DateTime.now().millisecondsSinceEpoch}",
        type: "test",
        ingredients: ["Test Ingredient 1", "Test Ingredient 2"],
        nutrition: Nutrition(
          calories: 500,
          protein: 25,
          carbs: 60,
          fat: 15,
        ),
      );

      await HiveService.saveMeal(testMeal);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test meal created successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating test meal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("History & Analytics"),
          backgroundColor: Colors.green.shade200,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("History",style:TextStyle(color:Colors.black45)),
        backgroundColor: Color.fromRGBO(201, 223, 200, 1.0),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Plans Section
            if (_mealPlans.isNotEmpty) ...[
              const Text("Saved Meal Plans",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._mealPlans.map((mealPlan) => Card(
                child: ExpansionTile(
                  title: Text("Meal Plan - ${_formatDate(mealPlan.dateTime)}"),
                  subtitle: Text("${mealPlan.meals.length} meals | ${mealPlan.totalNutrition.calories} calories"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...mealPlan.meals.map((meal) => ListTile(
                            title: Text("${meal.type.toUpperCase()}: ${meal.mealName}"),
                            subtitle: Text("${meal.nutrition.calories} cal | P: ${meal.nutrition.protein}g | C: ${meal.nutrition.carbs}g | F: ${meal.nutrition.fat}g"),
                          )),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total: ${mealPlan.totalNutrition.calories} cal"),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteMealPlan(mealPlan),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 24),
            ],

            // Individual Meals Section styled as cards list
            if (_mealHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No meals recorded yet. Start by analyzing food photos!"),
                ),
              )
            else
              ..._mealHistory.map((meal) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${meal.nutrition.calories} Kcal",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "P ${meal.nutrition.protein}g  C ${meal.nutrition.carbs}g  F ${meal.nutrition.fat}g",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_formatDate(meal.dateTime), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: () {},
                  ),
                  onLongPress: () => _deleteMeal(meal),
                ),
              )),
            const SizedBox(height: 24),

            // Analytics / chart
            if (_weeklyTrends.isNotEmpty) ...[
              const Text("Weekly Nutrition Trends",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 200, child: _CalorieChart(trends: _weeklyTrends)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _CalorieChart extends StatelessWidget {
  final List<Map<String, dynamic>> trends;

  const _CalorieChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    // Always try to render; make it resilient to empty/zero data
    if (trends.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text("No weekly data yet")),
      );
    }

    final spots = trends.asMap().entries.map((entry) {
      final raw = entry.value['calories'];
      final y = (raw is num) ? raw.toDouble() : 0.0;
      return FlSpot(entry.key.toDouble(), y);
    }).toList();

    final caloriesList = trends.map((e) {
      final v = e['calories'];
      return (v is num) ? v.toInt() : 0;
    }).toList();
    final maxCalories = caloriesList.isEmpty
        ? 0
        : caloriesList.reduce((a, b) => a > b ? a : b);
    final double chartMaxY = (maxCalories == 0 ? 1000 : (maxCalories * 1.2)).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < trends.length) {
                  final date = trends[value.toInt()]['date'] as DateTime;
                  return Text('${date.day}/${date.month}');
                }
                return const Text('');
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}');
              },
              reservedSize: 32,
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (trends.length - 1).toDouble(),
        minY: 0,
        maxY: chartMaxY,
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            spots: spots,
            color: Colors.green.shade600,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
