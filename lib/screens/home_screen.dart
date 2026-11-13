import 'package:flutter/material.dart';
import 'package:project6/screens/pantry_screen.dart';
import 'package:project6/screens/plan_screen.dart';
import 'package:project6/screens/recipes_screen.dart';
import 'package:project6/screens/shopping_screen.dart';
import 'package:project6/services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Recipes', 'Plan', 'Shopping', 'Pantry'];

  @override
  void initState() {
    super.initState();
    // HomeScreen only appears after sign-in, so a user id exists here.
    FirestoreService.instance.seedStarterRecipesIfEmpty().catchError(
      (Object e, StackTrace st) {
        debugPrint('Seeding failed: $e\n$st');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          _titles[_index],
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const RecipesScreen(),
          PlanScreen(onGenerated: () => setState(() => _index = 2)),
          ShoppingScreen(onGoToPlan: () => setState(() => _index = 1)),
          const PantryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, size: 28),
            selectedIcon: Icon(Icons.menu_book, size: 28),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, size: 28),
            selectedIcon: Icon(Icons.calendar_month, size: 28),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined, size: 28),
            selectedIcon: Icon(Icons.shopping_cart, size: 28),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined, size: 28),
            selectedIcon: Icon(Icons.kitchen, size: 28),
            label: 'Pantry',
          ),
        ],
      ),
    );
  }
}
