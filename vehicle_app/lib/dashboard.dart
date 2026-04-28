// lib/dashboard.dart
//
// Vehicle Hub — central dashboard with 7 cards + profile header.
// Requires login first (main.dart handles auth routing).

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth/login_page.dart';
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
    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF283593)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header with profile + logout ─────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      // Profile avatar — tap to open ProfilePage
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + email
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilePage(),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName.isNotEmpty
                                    ? 'Hi, $_userName 👋'
                                    : 'Vehicle Hub',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_userEmail.isNotEmpty)
                                Text(
                                  _userEmail,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Logout button
                      IconButton(
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white70,
                        ),
                        tooltip: 'Logout',
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ),

                // Sub-title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    'Select a service to get started',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Divider(
                    color: Colors.white.withOpacity(0.2),
                    thickness: 1,
                  ),
                ),

                // ── Card grid ────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: MediaQuery.sizeOf(context).width < 380
                          ? 0.74
                          : 0.82,
                      children: [
                        // Card 1: Vehicle Troubleshooting
                        _DashCard(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Vehicle\nTroubleshooting',
                          description:
                              'AI chat diagnosis for your vehicle issues',
                          gradientColors: const [
                            Color(0xFF42A5F5),
                            Color(0xFF1976D2),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          ),
                        ),

                        // Card 2: Damage Assessment
                        _DashCard(
                          icon: Icons.car_crash_rounded,
                          label: 'Damage\nAssessment',
                          description: 'Damage & repair cost estimation',
                          gradientColors: const [
                            Color(0xFFEF5350),
                            Color(0xFFC62828),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleDamageHomePage(),
                            ),
                          ),
                        ),

                        // Card 3: Claim History
                        _DashCard(
                          icon: Icons.history_rounded,
                          label: 'Claim\nHistory',
                          description:
                              'View all past submitted insurance claims',
                          gradientColors: const [
                            Color(0xFF26A69A),
                            Color(0xFF00695C),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClaimHistoryPage(baseApiUrl: _baseApiUrl),
                            ),
                          ),
                        ),

                        // Card 4: Insurer Dashboard
                        // _DashCard(
                        //   icon: Icons.business_center_rounded,
                        //   label: 'Insurer\nDashboard',
                        //   description:
                        //       'Review claims and submit final decisions',
                        //   gradientColors: const [
                        //     Color(0xFF7E57C2),
                        //     Color(0xFF4527A0),
                        //   ],
                        //   onTap: () => Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (_) =>
                        //           InsurerDashboardPage(baseApiUrl: _baseApiUrl),
                        //     ),
                        //   ),
                        // ),

                        // Card 5: RoadResQ
                        _DashCard(
                          icon: Icons.car_repair,
                          label: 'RoadResQ\nAssistance',
                          description:
                              'Roadside help: towing, spare parts & garages',
                          gradientColors: const [
                            Color(0xFFFF7043),
                            Color(0xFFBF360C),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const road_resq.HomeScreen(),
                            ),
                          ),
                        ),

                        // Card 6: Car Care Services
                        _DashCard(
                          icon: Icons.local_car_wash_rounded,
                          label: 'Car Care\nServices',
                          description:
                              'Wash, detailing, maintenance, and nearby service points',
                          gradientColors: const [
                            Color(0xFF0F766E),
                            Color(0xFF134E4A),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const car_care.CarCareDashboardPage(),
                            ),
                          ),
                        ),

                        // Card 7: GuardianLink
                        _DashCard(
                          icon: Icons.shield_rounded,
                          label: 'GuardianLink\nSafety',
                          description:
                              'Accident alerts, live tracking & emergency response',
                          gradientColors: const [
                            Color(0xFF1E88E5),
                            Color(0xFF1A237E),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const guardian_link.SplashScreen(),
                            ),
                          ),
                        ),

                        // Card 8: Emergency
                        _DashCard(
                          icon: Icons.emergency_rounded,
                          label: 'Emergency',
                          description:
                              'Open emergency alerts, tracking, and response tools',
                          gradientColors: const [
                            Color(0xFFD32F2F),
                            Color(0xFF7F1D1D),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const guardian_link.SplashScreen(),
                            ),
                          ),
                        ),

                        // Card 9: Profile
                        _DashCard(
                          icon: Icons.manage_accounts_rounded,
                          label: 'My\nProfile',
                          description:
                              'View and edit your personal information',
                          gradientColors: const [
                            Color(0xFF43A047),
                            Color(0xFF1B5E20),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilePage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Footer ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                  child: Center(
                    child: Text(
                      'Vehicle Hub © 2026. All rights reserved.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable card widget ────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _DashCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 210;
        final isVeryCompact = constraints.maxHeight < 190;
        final cardPadding = isVeryCompact ? 14.0 : (isCompact ? 16.0 : 18.0);
        final iconPadding = isVeryCompact ? 8.0 : (isCompact ? 10.0 : 12.0);
        final iconSize = isVeryCompact ? 22.0 : (isCompact ? 24.0 : 28.0);
        final labelFontSize = isVeryCompact ? 13.0 : (isCompact ? 14.0 : 15.0);
        final descriptionFontSize = isVeryCompact
            ? 9.0
            : (isCompact ? 10.0 : 11.0);
        final descriptionLines = isCompact ? 1 : 2;
        final labelSpacing = isVeryCompact ? 3.0 : (isCompact ? 4.0 : 6.0);
        final actionSpacing = isVeryCompact ? 6.0 : (isCompact ? 8.0 : 10.0);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.12),
              highlightColor: Colors.white.withOpacity(0.06),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: iconSize),
                    ),
                    const Spacer(),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: labelSpacing),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: descriptionFontSize,
                            height: 1.35,
                          ),
                          maxLines: descriptionLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: actionSpacing),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isVeryCompact ? 4 : 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: isVeryCompact ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
