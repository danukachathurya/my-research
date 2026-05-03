// lib/dashboard.dart
//
// Modern Minimal Dashboard — Clean, scalable UI

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth/login_page.dart';
import 'auth/auth_colors.dart';
import 'common/api_config.dart';
import 'dashboard/dashboard.dart' as car_care;
import 'dashboard/profile_page.dart';
import 'screens/home_screen.dart';
import 'vehicle_damage/vehicle_damage_home.dart';
import 'vehicle_damage/claim_history_page.dart';
import 'road_resq/screens/home_screen.dart' as road_resq;
import 'guardian_link/screens/splash_screen.dart' as guardian_link;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userEmail = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null && mounted) {
        setState(() {
          _userName = (data['fullName'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  String get _baseApiUrl => ApiConfig.baseUrl;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final services = [
      ServiceItem(Icons.chat_bubble_outline, "Troubleshooting",
          const Color(0xFF3B82F6), () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }),
      ServiceItem(Icons.history, "Claim History",
          const Color(0xFF10B981), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClaimHistoryPage(baseApiUrl: _baseApiUrl),
          ),
        );
      }),
      ServiceItem(Icons.car_repair, "RoadResQ",
          const Color(0xFFF97316), () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const road_resq.HomeScreen()));
      }),
      ServiceItem(Icons.local_car_wash, "Car Care",
          const Color(0xFF0F766E), () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const car_care.CarCareDashboardPage()));
      }),
      ServiceItem(Icons.shield, "GuardianLink",
          const Color(0xFF2563EB), () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const guardian_link.SplashScreen()));
      }),
      ServiceItem(Icons.person, "Profile",
          const Color(0xFF22C55E), () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfilePage()));
      }),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ─── HEADER ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty
                              ? "Hello, $_userName 👋"
                              : "Welcome 👋",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "What do you need today?",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                  )
                ],
              ),

              const SizedBox(height: 20),

              // ─── GRID ─────────────────────────────
              Expanded(
                child: GridView.builder(
                  itemCount: services.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = services[index];

                    return ModernServiceCard(
                      icon: item.icon,
                      label: item.label,
                      color: item.color,
                      onTap: item.onTap,
                    );
                  },
                ),
              ),

              // ─── FOOTER ─────────────────────────────
              const Text(
                "Vehicle Hub © 2026",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            ],
          ),
        ),
      ),
    );
  }
}

//
// ─── SERVICE MODEL ─────────────────────────────
//

class ServiceItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  ServiceItem(this.icon, this.label, this.color, this.onTap);
}

//
// ─── MODERN CARD ─────────────────────────────
//

class ModernServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ModernServiceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // icon box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),

              const Spacer(),

              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 4),

              Icon(
                Icons.arrow_forward,
                size: 16,
                color: color.withOpacity(0.7),
              )
            ],
          ),
        ),
      ),
    );
  }
}