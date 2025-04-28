import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/venue_utils.dart';

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

  // Map to convert frontend types to backend types
  final Map<String, String> accessibilityTypeMap = {
    'Trains': 'train',
    'Trams': 'tram',
    'Healthcare': 'healthcare',
    'Toilets': 'toilet',
  };

  String _normalizeAccessibilityType(String type) {
    // Remove any 's' at the end and convert to lowercase
    return accessibilityTypeMap[type] ?? type.toLowerCase().replaceAll(RegExp(r's$'), '');
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final accessibilityType = _normalizeAccessibilityType(widget.venueData['Accessibility_Type_Name']);
      
      // 1. Get the upload URL from backend
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/generate-upload-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'filename': _selectedImage!.name,
          'latitude': widget.venueData['Location_Lat'],
          'longitude': widget.venueData['Location_Lon'],
          'accessibility_type': accessibilityType,
          'content_type': 'image/jpeg',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get upload URL: ${response.body}');
      }

      final uploadData = jsonDecode(response.body);
      final uploadUrl = uploadData['upload_url'];
      final publicUrl = uploadData['public_url'];

      // 2. Upload the image to S3 using the pre-signed URL
      final file = File(_selectedImage!.path);
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        body: await file.readAsBytes(),
        headers: {
          'Content-Type': 'image/jpeg',
        },
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to upload image to S3');
      }

      // Clear the selected image after successful upload
      setState(() {
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venueData;
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload for ${extractVenueName(venue) ?? 'Venue'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Images',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (extractVenueType(venue) != null)
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Text('Type: ${extractVenueType(venue)}', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    // Name widget logic
                    (() {
                      final nameValue = extractVenueName(venue);
                      if (nameValue != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.label, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('Name: $nameValue', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    })(),
                    if (venue['Location_Lat'] != null && venue['Location_Lon'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Text('Location: ${venue['Location_Lat']}, ${venue['Location_Lon']}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Text('Select Image',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedImage!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadImage,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            const Divider(height: 32),
            Text('Uploaded Images', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            // TODO: Show uploaded images for this venue here
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No uploaded images yet.'),
            ),
          ],
        ),
      ),
    );
  }
}