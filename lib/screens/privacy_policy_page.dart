import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pattern_painters.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    // Set status bar color to match header
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.blue,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          // Blue header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Hexagonal pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: CustomPaint(
                        painter: HexagonPatternPainter(),
                      ),
                    ),
                  ),
                  // Header content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Back button
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Back',
                              iconSize: 22,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Privacy Policy',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Add a SizedBox with the same width as the back button to balance the layout
                          const SizedBox(width: 44),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Privacy Policy Content
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            'Information We Collect',
                            'We collect information that you provide directly to us, including:\n\n'
                            '• Device ID and username for account management\n'
                            '• Location data to show nearby accessible locations\n'
                            '• Images you upload to help improve accessibility information\n'
                            '• Your votes and contributions to the accessibility game',
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            'How We Use Your Information',
                            'We use the information we collect to:\n\n'
                            '• Provide and improve our services\n'
                            '• Show relevant accessibility information\n'
                            '• Maintain and improve the accessibility database\n'
                            '• Track contributions and maintain the leaderboard',
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            'Data Storage and Security',
                            '• Your data is stored securely on our servers\n'
                            '• We use industry-standard security measures\n'
                            '• Images are moderated before being made public\n'
                            '• Location data is only used to show nearby locations',
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            'Your Rights',
                            'You have the right to:\n\n'
                            '• Access your personal data\n'
                            '• Request deletion of your data\n'
                            '• Opt out of data collection\n'
                            '• Contact us with privacy concerns',
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            'Contact Us',
                            'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                            'support@mobilitymate.com',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ],
    );
  }
} 