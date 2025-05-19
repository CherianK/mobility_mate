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
        Uri.parse('http://localhost:5000/api/uploads/device/${widget.deviceId}/images'),
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
                      image['image_url'],
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
                    image['location_name'] ?? 'Unknown Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Type: ${image['accessibility_type'] ?? 'Not specified'}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isApproved ? 'Approved: ' : 'Uploaded: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    _formatDate(isApproved ? image['approved_at'] : image['uploaded_at']),
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