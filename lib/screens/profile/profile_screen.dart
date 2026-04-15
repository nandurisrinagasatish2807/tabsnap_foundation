// ignore_for_file: prefer_const_constructors, unnecessary_const
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/constants.dart';
import '../../router/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile', style: AppTextStyles.displayMedium),
              const SizedBox(height: 24),

              // ── Profile card ───────────────────────────────
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get(),
                builder: (context, snapshot) {
                  String name = currentUser.email ?? 'User';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    name =
                        data?['name'] as String? ?? currentUser.email ?? 'User';
                  }

                  final initials = name
                      .trim()
                      .split(' ')
                      .where((w) => w.isNotEmpty)
                      .map((w) => w[0].toUpperCase())
                      .take(2)
                      .join();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AppTextStyles.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                currentUser.email ?? '',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Stats ──────────────────────────────────────
              const Text('Your stats', style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              _StatsRow(userId: currentUser.uid),

              const SizedBox(height: 24),

              // ── Settings ───────────────────────────────────
              const Text('Settings', style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.qr_code,
                label: 'Show My QR',
                onTap: () => _showMyQR(context, currentUser.uid),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Privacy',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                label: 'Report a Bug',
                onTap: () async {
                  final uri = Uri.parse('mailto:support@tabsnap.app');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── Sign out ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.logout,
                      color: AppColors.danger, size: 18),
                  label: Text(
                    'Sign out',
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'TabSnap v1.0.0',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyQR(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('My QR Code', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Other users can scan this to add you as a friend.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: const Color(0xFF00C853), width: 3), // Emerald
                ),
                child: QrImageView(
                  data: 'tabsnap://user/$uid',
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: AppColors.primary, // Navy
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String userId;
  const _StatsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .snapshots(),
      builder: (context, snapshot) {
        final expenseCount = snapshot.data?.docs.length ?? 0;

        double total = 0;
        if (snapshot.hasData && snapshot.data != null) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += (data['total'] as num?)?.toDouble() ?? 0;
          }
        }

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Expenses',
                value: '$expenseCount',
                icon: Icons.receipt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total split',
                value: '\$${total.toStringAsFixed(0)}',
                icon: Icons.pie_chart_outline,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent),
          ),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyMedium),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
