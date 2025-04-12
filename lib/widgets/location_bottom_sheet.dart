import 'package:flutter/material.dart';

import '../utils/tag_formatter.dart';
import '../utils/icon_utils.dart';

class LocationBottomSheet extends StatelessWidget {
  final Map<String, dynamic>? toilet;
  final Map<String, dynamic>? train;
  final Map<String, dynamic>? tram;
  final Map<String, dynamic>? hospital;
  final VoidCallback onClose;

  const LocationBottomSheet({
    super.key,
    this.toilet,
    this.train,
    this.tram,
    this.hospital,
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
                    child: _buildContent(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (train != null) return _buildIconGrid(context, train!, getTrainIcon, "Train Information");
    if (tram != null) return _buildIconGrid(context, tram!, getTramIcon, "Tram Information");
    if (toilet != null) return _buildIconGrid(context, toilet!, getToiletIcon, "Accessibility Features");
    if (hospital != null) return _buildHospitalInfo(context, hospital!);
    return const Center(child: Text("No marker selected"));
  }

  Widget _buildIconGrid(
    BuildContext context,
    Map<String, dynamic> data,
    IconData Function(String, dynamic) iconGetter,
    String title,
  ) {
    final Map<String, dynamic> tags = data['Tags'] ?? {};
    final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
    final List<MapEntry<String, dynamic>> orderedTags = [];

    final prioritizedKeys = [
      'wheelchair',
      'access',
      'parkingaccessible',
      'toilets:wheelchair',
    ];

    for (final key in prioritizedKeys) {
      orderedTags.addAll(
        allTags.where((entry) => entry.key.toLowerCase() == key),
      );
    }

    final remaining = allTags.where((entry) =>
        !prioritizedKeys.contains(entry.key.toLowerCase())).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    orderedTags.addAll(remaining);

    if (orderedTags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No information available'),
      );
    }

    String displayTitle = title;
    final nameKey = tags.keys.firstWhere(
      (key) => key.toLowerCase() == 'name',
      orElse: () => '',
    );
    if (nameKey.isNotEmpty && tags[nameKey].toString().trim().isNotEmpty) {
      displayTitle = tags[nameKey].toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            displayTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
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

            return Card(
              elevation: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    formatTag(entry.key, entry.value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHospitalInfo(BuildContext context, Map<String, dynamic> data) {
    final tags = data['Tags'] ?? {};
    final fixedKeys = [
      'wheelchair',
      'healthcare',
      'name',
      'amenity',
      'opening_hours',
      'phone',
      'website'
    ];

    List<Widget> rows = [];

    for (String key in fixedKeys) {
      if (tags.containsKey(key)) {
        rows.add(_hospitalRow(key, tags[key]));
      }
    }

    final remainingKeys = tags.keys
        .where((k) => !fixedKeys.contains(k))
        .toList()
      ..sort();
    for (String key in remainingKeys) {
      rows.add(_hospitalRow(key, tags[key]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Hospital Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        ...rows,
      ],
    );
  }

  Widget _hospitalRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(getHospitalIcon(key, value), size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              formatTag(key, value),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
