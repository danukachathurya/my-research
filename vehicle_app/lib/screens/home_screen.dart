import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'dashboard_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade700],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // ── App icon + title ──────────────────────────────
                const Icon(
                  Icons.directions_car,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vehicle Assistant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to get help',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),

                const SizedBox(height: 48),

                // ── Option 1: Dashboard Scanner ───────────────────
                _FeatureCard(
                  icon: Icons.document_scanner,
                  title: 'Dashboard Scanner',
                  subtitle: 'Identify warning lights using your camera',
                  badgeText: 'AI • On-Device',
                  badgeColor: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScannerScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── Option 2: Chatbot ──────────────────────────────
                _FeatureCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Vehicle Troubleshooting',
                  subtitle: 'Chat with AI to diagnose your vehicle issues',
                  badgeText: chatProvider.isServerOnline ? 'Online' : 'Offline',
                  badgeColor: chatProvider.isServerOnline
                      ? Colors.green
                      : Colors.red,
                  statusWidget: !chatProvider.isServerOnline
                      ? Row(
                          children: [
                            const Text(
                              'Server offline — ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => chatProvider.refreshServerStatus(),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                  onTap: () => _startChat(context),
                ),

                const Spacer(),

                // ── Footer ────────────────────────────────────────
                const Text(
                  'Vehicle Assistant © 2026. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startChat(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    chatProvider
        .startConversationWithoutVehicle()
        .then((_) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting conversation: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }
}

// ─────────────────────────────────────────────────────────────────
// Reusable feature card widget
// ─────────────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback? onTap;
  final Widget? statusWidget;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
    this.statusWidget,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isDisabled ? 0.08 : 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(isDisabled ? 0.1 : 0.3),
            ),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),

              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (statusWidget != null) ...[
                      const SizedBox(height: 4),
                      statusWidget!,
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right side: badge + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isDisabled ? Colors.white30 : Colors.white70,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
