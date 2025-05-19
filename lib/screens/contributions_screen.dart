import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ContributionsScreen extends StatefulWidget {
  final String deviceId;

  const ContributionsScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _approvedImages = [];
  List<Map<String, dynamic>> _pendingImages = [];
  bool _isLoading = true;
  String? _error;
  final FocusNode _focusNode = FocusNode();
  
  // Base URL for API endpoints
  static const String _baseUrl = 'https://mobility-mate.onrender.com';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchImages();
    
    // Add focus listener to refresh data when page is focused
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _fetchImages();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/uploads/device/${widget.deviceId}/images'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final images = List<Map<String, dynamic>>.from(data['images']);
        
        setState(() {
          _approvedImages = images.where((img) => img['approved_status'] == true).toList();
          _pendingImages = images.where((img) => img['approved_status'] == false).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load images';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildImageList(List<Map<String, dynamic>> images, bool isApproved) {
    if (images.isEmpty) {
      return Center(
        child: Text(
          isApproved ? 'No approved images yet' : 'No pending images',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchImages,
      child: ListView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          final imageUrl = image['image_url']?.toString();
          final locationName = image['location_name']?.toString() ?? 'Unknown Location';
          final accessibilityType = image['accessibility_type']?.toString() ?? 'Not specified';
          final dateField = isApproved ? 'approved_at' : 'uploaded_at';
          final dateStr = image[dateField]?.toString();

          if (imageUrl == null) {
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(Icons.error_outline, size: 50, color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Invalid Image Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: Icon(Icons.error_outline, size: 50, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Type: $accessibilityType',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isApproved ? 'Approved: ' : 'Uploaded: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    _formatDate(dateStr),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Your Contributions'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Approved Images'),
              Tab(text: 'Pending Images'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImageList(_approvedImages, true),
                      _buildImageList(_pendingImages, false),
                    ],
                  ),
      ),
    );
  }
} 