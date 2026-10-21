import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';

enum NotificationType { queue, turn, doctor, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String time;
  final NotificationType type;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.read = false,
  });
}

///dummy data
class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  final List<AppNotification> items = [
    AppNotification(
      id: '1',
      title: 'Your turn is near',
      body: 'Only 2 patients are ahead of you. Please be ready.',
      time: '2 min ago',
      type: NotificationType.turn,
    ),
    AppNotification(
      id: '2',
      title: 'Token confirmed',
      body: 'You joined Dr. Ahmed\'s queue. Your token number is A-014.',
      time: '25 min ago',
      type: NotificationType.queue,
    ),
    AppNotification(
      id: '3',
      title: 'Doctor is now available',
      body: 'Dr. Sara Khan (Cardiology) has started consultation.',
      time: '1 hr ago',
      type: NotificationType.doctor,
      read: true,
    ),
    AppNotification(
      id: '4',
      title: 'Welcome to MediQueue',
      body: 'Your phone number is verified. You can now join any queue.',
      time: 'Yesterday',
      type: NotificationType.system,
      read: true,
    ),
  ];

  int get unread => items.where((n) => !n.read).length;

  void markRead(AppNotification n) {
    if (n.read) return;
    n.read = true;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in items) {
      n.read = true;
    }
    notifyListeners();
  }

  void remove(AppNotification n) {
    items.remove(n);
    notifyListeners();
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = NotificationStore.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Spacer(),
                          if (store.unread > 0)
                            TextButton(
                              onPressed: store.markAllRead,
                              child: const Text(
                                'Mark all as read',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.unread > 0
                            ? 'You have ${store.unread} unread'
                            : 'You are all caught up',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: store.items.isEmpty
                            ? _Empty()
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: store.items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final n = store.items[i];
                                  return Dismissible(
                                    key: ValueKey(n.id),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) => store.remove(n),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(
                                          alpha: .12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    child: _NotificationCard(
                                      n: n,
                                      onTap: () => store.markRead(n),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _NotificationCard({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (n.type) {
      NotificationType.turn => (Icons.notifications_active_rounded, Colors.orange),
      NotificationType.queue => (Icons.confirmation_number_rounded, AppColors.primary),
      NotificationType.doctor => (Icons.medical_services_rounded, Colors.teal),
      NotificationType.system => (Icons.verified_user_rounded, Colors.blueGrey),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.read ? Colors.white : AppColors.primary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: n.read
                ? AppColors.cardBorder
                : AppColors.primary.withValues(alpha: .25),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                n.read ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    n.time,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textGrey.withValues(alpha: .8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: AppColors.textGrey.withValues(alpha: .5),
          ),
          const SizedBox(height: 12),
          Text('No notifications yet',
              style: TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}