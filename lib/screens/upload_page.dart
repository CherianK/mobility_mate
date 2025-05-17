import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/venue_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadPage extends StatefulWidget {
  final Map<String, dynamic> venueData;
  const UploadPage({super.key, required this.venueData});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  List<Map<String, dynamic>> _approvedImages = [];

  @override
  void initState() {
    super.initState();
    _loadApprovedImages();
  }

  void _loadApprovedImages() {
    if (widget.venueData['Images'] != null) {
      final images = List<Map<String, dynamic>>.from(widget.venueData['Images']);
      _approvedImages = images.where((img) => img['approved_status'] == true).toList();
    }
  }

  final Map<String, String> accessibilityTypeMap = {
    'Trains': 'trains',
    'Trams': 'trams',
    'Healthcare': 'healthcare',
    'Toilets': 'toilets',
  };

  String _normalizeAccessibilityType(String type) {
    return accessibilityTypeMap[type] ?? type.toLowerCase().replaceAll(RegExp(r's$'), '');
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        _uploadImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);

    try {
      // Get device ID and username from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final username = prefs.getString('username_$deviceId');

      if (deviceId == null) {
        throw Exception('Device ID not found');
      }

      final accessibilityType = _normalizeAccessibilityType(widget.venueData['Accessibility_Type_Name']);
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/generate-upload-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'filename': _selectedImage!.name,
          'latitude': widget.venueData['Location_Lat'],
          'longitude': widget.venueData['Location_Lon'],
          'accessibility_type': accessibilityType,
          'content_type': 'image/jpeg',
          'device_id': deviceId,
          'username': username,
        }),
      );

      if (response.statusCode != 200) throw Exception('Failed to get upload URL: ${response.body}');
      final uploadData = jsonDecode(response.body);
      final uploadUrl = uploadData['upload_url'];

      final file = File(_selectedImage!.path);
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        body: await file.readAsBytes(),
        headers: {'Content-Type': 'image/jpeg'},
      );

      if (uploadResponse.statusCode != 200) throw Exception('Failed to upload image to S3');

      setState(() => _selectedImage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully! Awaiting approval.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venueData;

    return Scaffold(
      appBar: AppBar(title: Text('Upload for ${extractVenueName(venue) ?? 'Venue'}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Venue Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (extractVenueType(venue) != null)
                  ListTile(leading: const Icon(Icons.category_outlined), title: const Text('Type'), subtitle: Text(extractVenueType(venue)!)),
                if (extractVenueName(venue) != null)
                  ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Name'), subtitle: Text(extractVenueName(venue)!)),
                if (venue['Location_Lat'] != null && venue['Location_Lon'] != null)
                  ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Location'),
                      subtitle: Text('${venue['Location_Lat']}, ${venue['Location_Lon']}')),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Approved Images', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_approvedImages.isEmpty)
            Text('No approved images yet.', style: Theme.of(context).textTheme.bodyLarge)
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _approvedImages.length,
                itemBuilder: (context, index) {
                  final img = _approvedImages[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: img['image_url'],
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text('Upload New Image', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            )
        ]),
      ),
    );
  }
}