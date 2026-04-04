// lib/vehicle_damage/vehicle_damage_home.dart
//
// Tab shell for the Damage Assessment feature (from Flutter app 1).
// Replaces the old CustomerShell that lived in app 1's main.dart.

import 'package:flutter/material.dart';
import '../common/api_config.dart';
import 'claim_history_page.dart';
import 'vehicle_damage_assess_page.dart';

class VehicleDamageHomePage extends StatefulWidget {
  const VehicleDamageHomePage({super.key});

  @override
  State<VehicleDamageHomePage> createState() => _VehicleDamageHomePageState();
}

class _VehicleDamageHomePageState extends State<VehicleDamageHomePage> {
  int _selectedIndex = 0;

  String get _baseApiUrl => ApiConfig.baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Assess tab stays alive — preserves form state + results
          Offstage(
            offstage: _selectedIndex != 0,
            child: const VehicleDamageAssessPage(),
          ),
          // History tab rebuilds on every open → always fetches fresh data
          if (_selectedIndex == 1) ClaimHistoryPage(baseApiUrl: _baseApiUrl),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Assess',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'History'),
        ],
      ),
    );
  }
}
