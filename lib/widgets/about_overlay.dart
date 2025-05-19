import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AboutOverlay extends StatelessWidget {
  const AboutOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withOpacity(0.40),
              ),
            ),
          ),
          // About card
          Positioned(
            left: 20,
            right: 20,
            top: size.height * 0.30,
            child: Material(
              color: isDark ? theme.cardColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? theme.primaryColor.withOpacity(0.5) : Colors.blue.shade100,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? theme.primaryColor.withOpacity(0.2) : Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: isDark ? Colors.white : Colors.blue.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'About Mobility Mate',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.blue.shade900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mobility Mate is a community-driven platform that helps people with mobility needs find accessible locations and share their experiences.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.blue.shade700,
                        foregroundColor: isDark ? theme.primaryColor : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
} 