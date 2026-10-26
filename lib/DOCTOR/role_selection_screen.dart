import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'app_user.dart';

/// Shown only on the very first app open (until a role is saved).
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({
    super.key,
    required this.onPatient,
    required this.onDoctor,
  });

  final VoidCallback onPatient;
  final VoidCallback onDoctor;

  Future<void> _choose(UserRole role, VoidCallback next) async {
    await RoleStorage.save(role);
    next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome to MediQueue',
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text('How would you like to continue?',
                      style: AppTypography.normaltext
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  _RoleCard(
                    icon: Icons.person_outline,
                    title: "I'm a Patient",
                    subtitle: 'Join a queue and track your token live',
                    onTap: () => _choose(UserRole.patient, onPatient),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    title: "I'm a Doctor",
                    subtitle: 'Manage your queue and availability',
                    onTap: () => _choose(UserRole.doctor, onDoctor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTypography.normaltext.copyWith(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}