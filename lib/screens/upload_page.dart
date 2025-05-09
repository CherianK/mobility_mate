import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/venue_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  List<Map<String, dynamic>> _existingImages = [];

  @override
  void initState() {
    super.initState();
    _loadExistingImages();
  }

  void _loadExistingImages() {
    if (widget.venueData['Images'] != null) {
      setState(() {
        _existingImages = List<Map<String, dynamic>>.from(widget.venueData['Images']);
      });
    }
  }

  // Map to convert frontend types to backend types
  final Map<String, String> accessibilityTypeMap = {
    'Trains': 'trains',
    'Trams': 'trams',
    'Healthcare': 'healthcare',
    'Toilets': 'toilets',
  };

  String _normalizeAccessibilityType(String type) {
    // Remove any 's' at the end and convert to lowercase
    return accessibilityTypeMap[type] ?? type.toLowerCase().replaceAll(RegExp(r's$'), '');
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
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

      // Add the new image to the existing images list
      setState(() {
        _existingImages.add({
          'image_url': publicUrl,
          'image_upload_time': DateTime.now().toUtc().toIso8601String() + 'Z',
          'approved_status': false,
          'image_approved_time': null
        });
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Venue Details',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (extractVenueType(venue) != null)
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('Type'),
                        subtitle: Text(extractVenueType(venue)!),
                      ),
                    if (extractVenueName(venue) != null)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: const Text('Name'),
                        subtitle: Text(extractVenueName(venue)!),
                      ),
                    if (venue['Location_Lat'] != null && venue['Location_Lon'] != null)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Location'),
                        subtitle: Text('${venue['Location_Lat']}, ${venue['Location_Lon']}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Upload Images',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_existingImages.isNotEmpty) ...[
                      Text('Existing Images',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImages.length,
                          itemBuilder: (context, index) {
                            final image = _existingImages[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: image['image_url'],
                                      height: 120,
                                      width: 120,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_selectedImage == null)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No image selected',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.file(
                              File(_selectedImage!.path),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => setState(() => _selectedImage = null),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Select Image'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_selectedImage != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _uploadImage,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}