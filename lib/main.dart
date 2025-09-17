import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'features/food_scan/presentation/food_scan_screen.dart';
import 'historypage.dart';
import 'mealplanning.dart';
import 'models/meal_plan.dart';
import 'services/hive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Proceed without env; UI will inform if key is missing
  }
  
  // Initialize Hive
  await HiveService.init();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Prepare healthy meal",
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
      theme: ThemeData(
        useMaterial3: true,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color.fromRGBO(230, 255, 230, 1.0),
          selectedItemColor: Color.fromRGBO(5, 5, 5, 1.0),
          unselectedItemColor: Colors.grey[600],
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white70,
          surfaceTint: Colors.transparent,
        ),
      ),
    );
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Screens for tabs
  final List<Widget> _pages = [
    const HomePage(),
    const MealPlanningPage(),
    const HistoryPage(),
  ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Change screen when tab changes
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        selectedItemColor: Color.fromRGBO(103, 101, 101, 1.0),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: "Meal Plan",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "History",
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _todayCalories = 0;
  int _todayProtein = 0;
  int _todayCarbs = 0;
  int _todayFat = 0;
  int _todayMeals = 0;
  List<Meal> _todayMealsList = [];

  Future<void> _loadToday() async {
    final today = DateTime.now();
    final totals = HiveService.getCombinedDailyNutritionSummary(today);
    final mealCount = HiveService.getCombinedMealCountForDate(today);
    final meals = HiveService.getMealsByDate(today);

    // <-- you need this method

    setState(() {
      _todayCalories = totals['calories'] ?? 0;
      _todayProtein = totals['protein'] ?? 0;
      _todayCarbs = totals['carbs'] ?? 0;
      _todayFat = totals['fat'] ?? 0;
      _todayMeals = mealCount;
      _todayMealsList = meals;
    });
  }
  @override
  void initState() {
    super.initState();

    // test meals
    _todayMealsList = [
      Meal(
        mealName: "Chocolate Cake with Berries",
        nutrition: Nutrition(calories: 450, protein: 6, carbs: 50, fat: 25),
        dateTime: DateTime.now().subtract(const Duration(minutes: 20)), type: '', ingredients: [],
      ),
      Meal(
        mealName: "Grilled Chicken Salad",
        nutrition: Nutrition(calories: 320, protein: 35, carbs: 15, fat: 12),
        dateTime: DateTime.now().subtract(const Duration(hours: 2)), type: '', ingredients: [],
      ),
    ];

    _todayCalories = 450 + 320;
    _todayProtein = 6 + 35;
    _todayCarbs = 50 + 15;
    _todayFat = 25 + 12;
    _todayMeals = _todayMealsList.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Card
            SizedBox(height:60),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 1.0),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Profile Picture
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage: AssetImage("assets/profile.jpg"),
                      ),
                      const SizedBox(width: 12),
                      // Texts
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Welcome back,",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "Tanya Jonsson",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Notification Bell
                  IconButton(
                    onPressed: () {
                      // TODO: Handle notifications
                    },
                    icon: const Icon(Icons.notifications_none, size: 26, color: Colors.black),
                  ),
                ],
              ),
            ),

            //SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "   Today",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: _loadToday,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            // Dashboard card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color.fromRGBO(225, 235, 244, 1.0),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Calories left
                  CircularPercentIndicator(
                    radius: 70,
                    lineWidth: 12,
                    percent: (_todayCalories / 2500).clamp(0.0, 1.0),
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${2500 - _todayCalories}",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text("Calories left", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    progressColor: Colors.black,
                    backgroundColor: Colors.grey.shade400,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 20),

                  // Macros row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroCircle("Protein", _todayProtein, 170, Colors.pinkAccent),
                      _macroCircle("Carbs", _todayCarbs, 270, Colors.orangeAccent),
                      _macroCircle("Fat", _todayFat, 48, Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),
            // Recently Logged Meals Section
            if (_todayMealsList.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "   Recently Logged",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
             // const SizedBox(height: 12),

              ..._todayMealsList.map((meal) => Card(
                color:Color.fromRGBO(237, 243, 248, 1.0),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ListTile(
                    title: Text(meal.mealName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          "${meal.nutrition.calories} calories",
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "P ${meal.nutrition.protein}g · C ${meal.nutrition.carbs}g · F ${meal.nutrition.fat}g",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Text(
                      "${meal.dateTime.hour}:${meal.dateTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              )),
            ],

          ],
        ),
      ),
      floatingActionButton: Container(
        width: 65,
        height: 65,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(129, 190, 211, 1.0),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodScanScreen()),
            );
            if (result != null) {
              print("Scanned data: $result");
            }
            await _loadToday();
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  Widget _macroCircle(String label, int value, int goal, Color color) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 35,
          lineWidth: 6,
          percent: (value / goal).clamp(0.0, 1.0),
          center: Text(
            "${goal - value}g",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          progressColor: color,
          backgroundColor: Colors.grey.shade400,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
        Text("left", style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }


  Widget _macroTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
