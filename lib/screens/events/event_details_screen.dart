import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../services/database_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  _EventDetailsScreenState createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isRegistered = false;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    try {
      final status = await _databaseService.checkEventRegistrationStatus(
        widget.event.id,
        'currentUserId', // Replace with actual current user ID
      );

      setState(() {
        _isRegistered = status['isRegistered'] ?? false;
      });
    } catch (e) {
      print('Error checking registration status: $e');
    }
  }

  Future<void> _handleRegistration() async {
    try {
      if (_isRegistered) {
        // Show unregister confirmation
        final confirm = await _showUnregisterConfirmation();
        if (confirm) {
          await _databaseService.unregisterFromEvent(
            widget.event.id,
            'currentUserId', // Replace with actual current user ID
          );
          setState(() {
            _isRegistered = false;
          });
        }
      } else {
        await _databaseService.registerForEvent(
          widget.event.id,
          'currentUserId', // Replace with actual current user ID
        );
        setState(() {
          _isRegistered = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showUnregisterConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister from Event'),
        content: const Text('Are you sure you want to unregister?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unregister'),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null) return;

    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch URL: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventHeader(),
                  const SizedBox(height: 16),
                  _buildEventDetails(),
                  const SizedBox(height: 16),
                  _buildDescriptionSection(),
                  const SizedBox(height: 16),
                  _buildAdditionalDetails(),
                  const SizedBox(height: 24),
                  _buildRegistrationButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildEventImage(),
        title: Text(
          widget.event.title,
          style: TextStyle(
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage() {
    return widget.event.imageUrl != null
        ? CachedNetworkImage(
      imageUrl: widget.event.imageUrl!,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    )
        : Container(
      color: Colors.blue[100],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildEventHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.event.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        _buildEventTags(),
      ],
    );
  }

  Widget _buildEventTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (widget.event.isOnline)
          _buildTag('Online', Icons.videocam, Colors.green),
        if (widget.event.isAccMembersOnly)
          _buildTag('Members Only', Icons.lock, Colors.red),
        _buildTag(widget.event.category, Icons.category, Colors.blue),
      ],
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: color),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }

  Widget _buildEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(
          Icons.calendar_today,
          'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.event.dateTime)}',
        ),
        _buildDetailRow(
          Icons.access_time,
          'Time: ${widget.event.timeRange}',
        ),
        _buildDetailRow(
          widget.event.isOnline ? Icons.videocam : Icons.location_on,
          'Location: ${widget.event.location}',
        ),
        if (widget.event.presenter != null)
          _buildDetailRow(
            Icons.person,
            'Presenter: ${widget.event.presenter}',
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.event.description,
          style: TextStyle(color: Colors.grey[800], height: 1.5),
        ),
      ],
    );
  }

  Widget _buildAdditionalDetails() {
    return ExpansionTile(
      title: const Text('Additional Information'),
      children: [
        if (widget.event.guidelines.isNotEmpty)
          _buildInfoSection('Guidelines', widget.event.guidelines),
        if (widget.event.requirements.isNotEmpty)
          _buildInfoSection('Requirements', widget.event.requirements),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildBulletPoint(item)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(color: Colors.blue[700], fontSize: 16),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildRegistrationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRegistered ? Colors.red : Colors.blue[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          _isRegistered ? 'Unregister' : 'Register Now',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).animate()
        .fadeIn(duration: 300.ms)
        .scaleXY(begin: 0.9, end: 1.0); // Use scaleXY instead of scale
  }
}