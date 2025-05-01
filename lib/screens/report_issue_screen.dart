import 'package:flutter/material.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ReportIssueScreenState createState() => ReportIssueScreenState();
}

class ReportIssueScreenState extends State<ReportIssueScreen> with SingleTickerProviderStateMixin {
  // Toggle options
  Map<String, bool> issueToggles = {
    'No wheelchair access': false,
    'No accessible toilet': false,
    'No ramp/lift': false,
    'Info is outdated': false,
    'Other issue': false,
  };

  // Radio values
  String? issueType;
  String? knowledgeSource;
  bool isSubmitting = false;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> issueTypeOptions = [
    {'label': "Doesn't exist", 'icon': Icons.close, 'color': Colors.red},
    {'label': "Partly correct", 'icon': Icons.adjust, 'color': Colors.orange},
    {'label': "Unclear info", 'icon': Icons.help_outline, 'color': Colors.blue},
    {'label': "Safety concern", 'icon': Icons.warning_amber, 'color': Colors.red},
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void submitForm() async {
    if (issueType == null || knowledgeSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Please complete all required selections.',
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
  }

  Icon _getToggleIcon(String label) {
    switch (label) {
      case 'No wheelchair access':
        return Icon(Icons.wheelchair_pickup, color: Colors.blue.withOpacity(0.7), size: 20);
      case 'No accessible toilet':
        return Icon(Icons.accessible, color: Colors.green.withOpacity(0.7), size: 20);
      case 'No ramp/lift':
        return Icon(Icons.elevator, color: Colors.purple.withOpacity(0.7), size: 20);
      case 'Info is outdated':
        return Icon(Icons.list_alt, color: Colors.orange.withOpacity(0.7), size: 20);
      case 'Other issue':
        return Icon(Icons.help, color: Colors.grey.withOpacity(0.7), size: 20);
      default:
        return Icon(Icons.report, color: Colors.red.withOpacity(0.7), size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report an Issue'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help us improve',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your feedback helps make our app better for everyone',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s wrong?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: issueToggles.entries.map((entry) {
                        return SwitchListTile(
                          secondary: _getToggleIcon(entry.key),
                          title: Text(entry.key),
                          value: entry.value,
                          activeColor: Colors.blue,
                          onChanged: (bool val) {
                            setState(() {
                              issueToggles[entry.key] = val;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 24),
                  Text(
                    'Issue type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: issueTypeOptions.map((option) {
                        return RadioListTile<String>(
                          value: option['label'],
                          groupValue: issueType,
                          title: Row(
                            children: [
                              Icon(option['icon'], color: option['color'].withOpacity(0.7), size: 20),
                              SizedBox(width: 8),
                              Text(option['label']),
                            ],
                          ),
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setState(() {
                              issueType = val;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 24),
                  Text(
                    'How do you know?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: knowledgeOptions.map((source) {
                        return RadioListTile<String>(
                          value: source,
                          groupValue: knowledgeSource,
                          title: Text(source),
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setState(() {
                              knowledgeSource = val;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 32),
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
                            label: Text(isSubmitting ? 'Submitting...' : 'Submit Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
