import 'package:flutter/material.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ReportIssueScreenState createState() => ReportIssueScreenState();
}

class ReportIssueScreenState extends State<ReportIssueScreen> {
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

  final List<Map<String, dynamic>> issueTypeOptions = [
    {'label': "Doesn't exist", 'icon': Icons.close},
    {'label': "Partly correct", 'icon': Icons.adjust},
    {'label': "Unclear info", 'icon': Icons.help_outline},
    {'label': "Safety concern", 'icon': Icons.warning_amber},
  ];

  final List<String> knowledgeOptions = [
    'I visited',
    'Someone told me',
    'Found online',
  ];

 void submitForm() {
  if (issueType == null || knowledgeSource == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Please complete all required selections.'),
      duration: Duration(seconds: 2),
    ));
    return;
  }

  // Show a brief success message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Report submitted successfully!'),
      duration: Duration(seconds: 1),
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
        return Icon(Icons.wheelchair_pickup);
      case 'No accessible toilet':
        return Icon(Icons.local_parking);
      case 'No ramp/lift':
        return Icon(Icons.elevator);
      case 'Info is outdated':
        return Icon(Icons.list_alt);
      case 'Other issue':
        return Icon(Icons.help);
      default:
        return Icon(Icons.report);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report an Issue'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What\'s wrong?',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),

            // Toggle switches with icons
            ...issueToggles.entries.map((entry) {
              return SwitchListTile(
                secondary: _getToggleIcon(entry.key),
                title: Text(entry.key),
                value: entry.value,
                onChanged: (bool val) {
                  setState(() {
                    issueToggles[entry.key] = val;
                  });
                },
              );
            }),

            SizedBox(height: 16),
            Text('Issue type',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),

            // Issue type radios
            ...issueTypeOptions.map((option) {
              return RadioListTile<String>(
                value: option['label'],
                groupValue: issueType,
                title: Row(
                  children: [
                    Icon(option['icon']),
                    SizedBox(width: 8),
                    Text(option['label']),
                  ],
                ),
                onChanged: (val) {
                  setState(() {
                    issueType = val;
                  });
                },
              );
            }),

            SizedBox(height: 16),
            Text('How do you know?',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),

            // Source of knowledge
            ...knowledgeOptions.map((source) {
              return RadioListTile<String>(
                value: source,
                groupValue: knowledgeSource,
                title: Text(source),
                onChanged: (val) {
                  setState(() {
                    knowledgeSource = val;
                  });
                },
              );
            }),

            SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: submitForm,
                icon: Icon(Icons.mail),
                label: Text('Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
