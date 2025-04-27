import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/tag_formatter.dart';
import '../screens/report_issue_screen.dart'; // Adjust this import if needed

class LocationBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;
  final IconData Function(String, dynamic) iconGetter;
  final VoidCallback onClose;

  const LocationBottomSheet({
    super.key,
    required this.data,
    required this.title,
    required this.iconGetter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.22) {
          onClose();
        }
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: _buildIconGrid(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconGrid(BuildContext context) {
    final Map<String, dynamic> tags = data['Tags'] ?? {};
    final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
    final prioritizedKeys = [
      'wheelchair',
      'access',
      'parkingaccessible',
      'toilets:wheelchair',
    ];

    final List<MapEntry<String, dynamic>> orderedTags = [
      ...prioritizedKeys
          .map((key) => allTags.where((entry) => entry.key.toLowerCase() == key))
          .expand((e) => e),
      ...allTags
          .where((entry) => !prioritizedKeys.contains(entry.key.toLowerCase()))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    ];

    if (orderedTags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No information available'),
      );
    }

    final lat = data['Location_Lat']?.toString() ?? '';
    final lon = data['Location_Lon']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportIssueScreen()),
                  );
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Share.share("Check this location: https://maps.google.com/?q=$lat,$lon");
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ),

        // Icon Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: orderedTags.length,
          itemBuilder: (context, index) {
            final entry = orderedTags[index];
            final icon = iconGetter(entry.key, entry.value);
            final tagText = formatTag(entry.key, entry.value);

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    contentPadding: const EdgeInsets.all(16),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 48, color: Theme.of(context).primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          tagText,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Card(
                elevation: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        tagText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}