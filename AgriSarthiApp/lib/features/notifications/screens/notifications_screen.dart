import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B1B1B)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1B1B1B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _sampleNotifications.length,
        itemBuilder: (context, index) {
          final n = _sampleNotifications[index];
          return _NotificationCard(data: n);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// NOTIFICATION MODEL
// ════════════════════════════════════════════════════════════════════

enum NotificationType {
  newScheme,
  approved,
  actionRequired,
  priceUpdate,
  deadline,
  appUpdate,
  profileUpdate,
}

class _NotificationData {
  final String title;
  final String description;
  final String timeAgo;
  final NotificationType type;

  const _NotificationData({
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.type,
  });
}

// ════════════════════════════════════════════════════════════════════
// SAMPLE DATA
// ════════════════════════════════════════════════════════════════════

final List<_NotificationData> _sampleNotifications = [
  const _NotificationData(
    title: 'New Scheme: Kisan Kalyan Yojana',
    description: 'Apply now for benefits up to ₹50,000.',
    timeAgo: 'Just now',
    type: NotificationType.newScheme,
  ),
  const _NotificationData(
    title: 'Application Approved',
    description: 'PM Fasal Bima Yojana application accepted.',
    timeAgo: '5m ago',
    type: NotificationType.approved,
  ),
  const _NotificationData(
    title: 'Action Required',
    description: 'Please verify your documents.',
    timeAgo: '1h ago',
    type: NotificationType.actionRequired,
  ),
  const _NotificationData(
    title: 'Mandi Price Update',
    description: 'Wheat prices up by ₹50/quintal.',
    timeAgo: '2h ago',
    type: NotificationType.priceUpdate,
  ),
  const _NotificationData(
    title: 'Deadline: Soil Health Card',
    description: 'Last date to apply is tomorrow.',
    timeAgo: 'Yesterday',
    type: NotificationType.deadline,
  ),
  const _NotificationData(
    title: 'App Update',
    description: 'New features added.',
    timeAgo: '2d ago',
    type: NotificationType.appUpdate,
  ),
  const _NotificationData(
    title: 'Profile Updated',
    description: 'Your profile changes were saved.',
    timeAgo: '3d ago',
    type: NotificationType.profileUpdate,
  ),
];

// ════════════════════════════════════════════════════════════════════
// NOTIFICATION CARD WIDGET
// ════════════════════════════════════════════════════════════════════

class _NotificationCard extends StatelessWidget {
  final _NotificationData data;
  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final iconInfo = _getIconInfo(data.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconInfo.bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(iconInfo.icon, color: iconInfo.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time ago
          Text(
            data.timeAgo,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _IconInfo _getIconInfo(NotificationType type) {
    switch (type) {
      case NotificationType.newScheme:
        return _IconInfo(
          icon: Icons.campaign_outlined,
          iconColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFFFF3E0),
        );
      case NotificationType.approved:
        return _IconInfo(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF2E7D32),
          bgColor: const Color(0xFFE8F5E9),
        );
      case NotificationType.actionRequired:
        return _IconInfo(
          icon: Icons.warning_amber_outlined,
          iconColor: const Color(0xFFC62828),
          bgColor: const Color(0xFFFFEBEE),
        );
      case NotificationType.priceUpdate:
        return _IconInfo(
          icon: Icons.bar_chart,
          iconColor: const Color(0xFF1565C0),
          bgColor: const Color(0xFFE3F2FD),
        );
      case NotificationType.deadline:
        return _IconInfo(
          icon: Icons.schedule,
          iconColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFFFF3E0),
        );
      case NotificationType.appUpdate:
        return _IconInfo(
          icon: Icons.info_outline,
          iconColor: const Color(0xFF1565C0),
          bgColor: const Color(0xFFE3F2FD),
        );
      case NotificationType.profileUpdate:
        return _IconInfo(
          icon: Icons.person_outline,
          iconColor: const Color(0xFF00897B),
          bgColor: const Color(0xFFE0F2F1),
        );
    }
  }
}

class _IconInfo {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _IconInfo(
      {required this.icon, required this.iconColor, required this.bgColor});
}
