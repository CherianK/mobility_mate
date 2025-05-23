import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/pattern_painters.dart';
import 'package:flutter/services.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ReportIssueScreenState createState() => ReportIssueScreenState();
}

class ReportIssueScreenState extends State<ReportIssueScreen> with SingleTickerProviderStateMixin {
  // Toggle options - Multiple selection allowed
  Map<String, bool> issueToggles = {
    'No wheelchair access': false,
    'No accessible toilet': false,
    'No ramp/lift': false,
    'Info is outdated': false,
    'Other issue': false,
  };

  // Single selection required
  String? issueType;
  String? knowledgeSource;
  bool isSubmitting = false;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> issueTypeOptions = [
    {'label': "Doesn't exist", 'color': Colors.red},
    {'label': "Partly correct", 'color': Colors.orange},
    {'label': "Unclear info", 'color': Colors.blue},
    {'label': "Safety concern", 'color': Colors.red},
  ];

  final List<String> knowledgeOptions = [
    'I visited',
    'Someone told me',
    'Found online',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Set status bar color to match header
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.blue,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void submitForm() async {
    bool hasIssues = issueToggles.values.any((value) => value);
    if (!hasIssues || issueType == null || knowledgeSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Please answer all questions before submitting.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 2),
          margin: EdgeInsets.all(8),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    await _animationController.forward();

    try {
      // Get device ID and username from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final username = prefs.getString('username_$deviceId');

      // Prepare report data
      final reportData = {
        'device_id': deviceId,
        'username': username,
        'issue_type': issueType,
        'knowledge_source': knowledgeSource,
        'issues': issueToggles.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
      };

      // Send report to server
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/report-issue'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(reportData),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to submit report: ${response.body}');
      }

      // Show a brief success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Report submitted successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Wait briefly then pop back to previous screen
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => isSubmitting = false);
      _animationController.reverse();
    }
  }

  void _toggleTheme() {
    final themeProvider = context.read<ThemeProvider>();
    final newMode = themeProvider.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    themeProvider.setThemeMode(newMode);
  }

  Widget _buildSelectionOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMultiple = false,
  }) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? (isDark ? Colors.white : theme.primaryColor)
                      : (isDark ? Colors.grey[400]! : Colors.grey.shade400),
                  width: 2,
                ),
                borderRadius: isMultiple ? BorderRadius.circular(4) : null,
                color: isSelected 
                    ? (isDark ? Colors.white.withOpacity(0.2) : theme.primaryColor.withOpacity(0.1))
                    : (isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.transparent),
              ),
              child: isSelected
                  ? Icon(
                      isMultiple ? Icons.check : Icons.circle,
                      size: 16,
                      color: isDark ? Colors.white : theme.primaryColor,
                    )
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

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
              child: Column(
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
                            const Text(
                              'Report an Issue',
                              style: TextStyle(
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
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your feedback helps make our app better for everyone',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                height: 1.4,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  _buildSectionHeader('What\'s wrong?', '(Select all that apply)'),
                  SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      shadowColor: Colors.black.withOpacity(0.1),
                    child: Column(
                      children: issueToggles.entries.map((entry) {
                        return _buildSelectionOption(
                          label: entry.key,
                          isSelected: entry.value,
                          onTap: () {
                            setState(() {
                              issueToggles[entry.key] = !entry.value;
                            });
                          },
                          isMultiple: true,
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 32),
                  _buildSectionHeader('Issue type', '(Select one)'),
                  SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      shadowColor: Colors.black.withOpacity(0.1),
                    child: Column(
                      children: issueTypeOptions.map((option) {
                        return _buildSelectionOption(
                          label: option['label'],
                          isSelected: issueType == option['label'],
                          onTap: () {
                            setState(() {
                              issueType = option['label'];
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 32),
                  _buildSectionHeader('How do you know?', '(Select one)'),
                  SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      shadowColor: Colors.black.withOpacity(0.1),
                    child: Column(
                      children: knowledgeOptions.map((source) {
                        return _buildSelectionOption(
                          label: source,
                          isSelected: knowledgeSource == source,
                          onTap: () {
                            setState(() {
                              knowledgeSource = source;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 40),
                  Center(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 - (_animationController.value * 0.1),
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting ? null : submitForm,
                            icon: isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.send),
                            label: Text(
                              isSubmitting ? 'Submitting...' : 'Submit Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildSectionHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
