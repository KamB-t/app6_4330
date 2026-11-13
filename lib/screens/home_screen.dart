import 'package:flutter/material.dart';
import 'package:project6/screens/recipes_screen.dart';
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
    FirestoreService.instance.seedStarterRecipesIfEmpty().then((_) {
    }).catchError((Object e, StackTrace st) {
      debugPrint('Seeding failed: $e\n$st');
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          RecipesScreen(),
          Center(child: Text('Plan (coming soon)')),
          Center(child: Text('Shopping (coming soon)')),
          Center(child: Text('Pantry (coming soon)')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Shopping'),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
        ],
      ),
    );
  }
}