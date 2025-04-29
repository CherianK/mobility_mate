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
       return Icon(Icons.wc);
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
       title: const Text('Report an Issue'),
     ),
     body: SingleChildScrollView(
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Header section
           Container(
             padding: const EdgeInsets.all(16),
             color: Colors.blue.shade50,
             child: const Text(
               'Help us improve accessibility information by reporting issues you encounter.',
               style: TextStyle(
                 fontSize: 16,
                 color: Colors.blue,
               ),
             ),
           ),
           const SizedBox(height: 16),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // What's wrong section
                 Text(
                   'What\'s wrong?',
                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.blue.shade700,
                       ),
                 ),
                 const SizedBox(height: 8),
                 Card(
                   elevation: 0,
                   color: Colors.grey.shade50,
                   child: Column(
                     children: issueToggles.entries.map((entry) {
                       return Column(
                         children: [
                           SwitchListTile(
                             secondary: _getToggleIcon(entry.key),
                             title: Text(entry.key),
                             value: entry.value,
                             onChanged: (bool val) {
                               setState(() {
                                 issueToggles[entry.key] = val;
                               });
                             },
                           ),
                           if (entry.key != issueToggles.keys.last)
                             const Divider(height: 1),
                         ],
                       );
                     }).toList(),
                   ),
                 ),
                 const SizedBox(height: 24),


                 // Issue type section
                 Text(
                   'Issue type',
                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.blue.shade700,
                       ),
                 ),
                 const SizedBox(height: 8),
                 Card(
                   elevation: 0,
                   color: Colors.grey.shade50,
                   child: Column(
                     children: issueTypeOptions.map((option) {
                       return Column(
                         children: [
                           RadioListTile<String>(
                             value: option['label'],
                             groupValue: issueType,
                             title: Row(
                               children: [
                                 Icon(option['icon'], color: Colors.blue.shade700),
                                 const SizedBox(width: 8),
                                 Text(option['label']),
                               ],
                             ),
                             onChanged: (val) {
                               setState(() {
                                 issueType = val;
                               });
                             },
                           ),
                           if (option != issueTypeOptions.last)
                             const Divider(height: 1),
                         ],
                       );
                     }).toList(),
                   ),
                 ),
                 const SizedBox(height: 24),


                 // How do you know section
                 Text(
                   'How do you know?',
                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Colors.blue.shade700,
                       ),
                 ),
                 const SizedBox(height: 8),
                 Card(
                   elevation: 0,
                   color: Colors.grey.shade50,
                   child: Column(
                     children: knowledgeOptions.map((source) {
                       return Column(
                         children: [
                           RadioListTile<String>(
                             value: source,
                             groupValue: knowledgeSource,
                             title: Text(source),
                             onChanged: (val) {
                               setState(() {
                                 knowledgeSource = val;
                               });
                             },
                           ),
                           if (source != knowledgeOptions.last)
                             const Divider(height: 1),
                         ],
                       );
                     }).toList(),
                   ),
                 ),
                 const SizedBox(height: 32),


                 // Submit button
                 Center(
                   child: ElevatedButton.icon(
                     onPressed: submitForm,
                     icon: const Icon(Icons.mail),
                     label: const Text('Submit Report'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blue,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(
                         horizontal: 32,
                         vertical: 16,
                       ),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(height: 16),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }
}
