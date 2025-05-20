import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pattern_painters.dart';

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
    
    // Add listener to update tab display when tab changes
    _tabController.addListener(_handleTabChange);
    
    // Add focus listener to refresh data when page is focused
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _fetchImages();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
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
        Uri.parse('https://mobility-mate.onrender.com/api/uploads/device/${widget.deviceId}/images'),
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

  // Handle tab change to update the UI
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Widget _buildImageList(List<Map<String, dynamic>> images, bool isApproved) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    if (images.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                    ? isApproved 
                      ? Colors.green[900]?.withOpacity(0.3) 
                      : Colors.orange[900]?.withOpacity(0.3)
                    : isApproved 
                      ? Colors.green[50] 
                      : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved ? Icons.check_circle_outline : Icons.hourglass_empty,
                  size: 48,
                  color: isDark 
                    ? isApproved 
                      ? Colors.green[300] 
                      : Colors.orange[300]
                    : isApproved 
                      ? Colors.green[700] 
                      : Colors.orange[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isApproved ? 'No Approved Images Yet' : 'No Pending Images',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark 
                    ? isApproved 
                      ? Colors.green[300] 
                      : Colors.orange[300]
                    : isApproved 
                      ? Colors.green[700] 
                      : Colors.orange[700],
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isApproved 
                  ? 'Your approved contributions will appear here.'
                  : 'Images awaiting approval will appear here.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isApproved) ...[
                const SizedBox(height: 24),
                Text(
                  'Pending images are under review by our team.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchImages,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
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
            margin: EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                          ? isApproved
                            ? Colors.green[900]?.withOpacity(0.7)
                            : Colors.orange[900]?.withOpacity(0.7)
                          : isApproved
                            ? Colors.green[100]
                            : Colors.orange[100],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isApproved ? Icons.check_circle : Icons.pending,
                            size: 16,
                            color: isDark
                              ? isApproved
                                ? Colors.green[300]
                                : Colors.orange[300]
                              : isApproved
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            isApproved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                ? isApproved
                                  ? Colors.green[300]
                                  : Colors.orange[300]
                                : isApproved
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.error_outline, size: 50, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark 
                        ? Colors.blue.withOpacity(0.1) 
                        : Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Type: $accessibilityType',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      SizedBox(width: 6),
                      Text(
                        isApproved ? 'Approved: ' : 'Uploaded: ',
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      Text(
                        _formatDate(dateStr),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
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
        body: SafeArea(
          child: Container(
            color: isDark ? Colors.grey[900] : Colors.white,
            child: Column(
              children: [
                // Blue header section
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Hexagonal pattern
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.1,
                          child: CustomPaint(
                            painter: HexagonPatternPainter(),
                          ),
                        ),
                      ),
                      // Header content
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Back button
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                  tooltip: 'Back',
                                  iconSize: 22,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Contributions',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Track images you\'ve shared with the community',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Tab bar
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Material(
                              color: Colors.transparent,
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                indicatorPadding: EdgeInsets.zero,
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                dividerHeight: 0,
                                splashBorderRadius: BorderRadius.circular(12),
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, size: 18),
                                        SizedBox(width: 6),
                                        Text('Approved'),
                                        SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _tabController.index == 0 
                                                ? Colors.blue.withOpacity(0.2) 
                                                : Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_approvedImages.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _tabController.index == 0 
                                                  ? Colors.blue 
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.hourglass_top, size: 18),
                                        SizedBox(width: 6),
                                        Text('Pending'),
                                        SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _tabController.index == 1 
                                                ? Colors.blue.withOpacity(0.2) 
                                                : Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_pendingImages.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _tabController.index == 1 
                                                  ? Colors.blue 
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Add spacing between header and content
                const SizedBox(height: 16),
                // Main content
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Container(
                                  padding: EdgeInsets.all(20),
                                  margin: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.red[900]?.withOpacity(0.3) : Colors.red[50],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: isDark ? Colors.red[300] : Colors.red[700],
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Error Loading Data',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.red[300] : Colors.red[700],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        _error!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _fetchImages,
                                        icon: Icon(Icons.refresh),
                                        label: Text('Try Again'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? Colors.red[700] : Colors.red[600],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildImageList(_approvedImages, true),
                                  _buildImageList(_pendingImages, false),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 