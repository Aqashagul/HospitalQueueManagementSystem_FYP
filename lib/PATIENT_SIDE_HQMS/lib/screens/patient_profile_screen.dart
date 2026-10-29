import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import 'welcome_screen.dart';
import 'terms_conditions_screen.dart';
import '../widgets/page_top_bar.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  bool _busy = false;
  bool _alerts = true;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(_auth.currentUser!.uid);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _alerts = p.getBool('queue_alerts') ?? true);
  }

  Future<void> _setAlerts(bool v) async {
    setState(() => _alerts = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('queue_alerts', v);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------- Photo ----------------
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final bytes = await file.readAsBytes();
      await _doc.set({
        'photoBase64': base64Encode(bytes),
      }, SetOptions(merge: true));
      _snack('Profile photo updated');
    } catch (_) {
      _snack('Could not update photo. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    try {
      setState(() => _busy = true);
      await _doc.update({'photoBase64': FieldValue.delete()});
      _snack('Profile photo removed');
    } catch (_) {
      _snack('Could not remove photo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPhotoSheet(bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              _Tile(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              _Tile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                _Tile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Remove photo',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Name ----------------
  Future<void> _editName(String current) async {
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditNameSheet(initial: current),
    );
    if (newName == null || newName == current) return;

    try {
      setState(() => _busy = true);
      await _auth.currentUser!.updateDisplayName(newName);
      await _doc.set({'name': newName}, SetOptions(merge: true));
      _snack('Name updated');
    } catch (_) {
      _snack('Could not update name. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------- Logout ----------------
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will need to verify your phone number again to log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
    try {
      // Forget the QR verification and any active queue entry, so the next
      // login starts from the scan screen again.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('qr_verified');
      await prefs.remove('active_entry_id');
      await _auth.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _doc.snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final name =
                    (data?['name'] as String?) ?? user.displayName ?? 'Patient';
                final phone = user.phoneNumber ?? (data?['phone'] ?? '-');
                final photoB64 = data?['photoBase64'] as String?;
                final hasPhoto = photoB64 != null && photoB64.isNotEmpty;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageTopBar(title: 'Profile', showBell: false),
                      const SizedBox(height: 18),

                      // ---- Header card ----
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: _cardDecoration(),
                        child: Column(
                          children: [
                            _Avatar(
                              name: name,
                              photoBase64: hasPhoto ? photoB64 : null,
                              busy: _busy,
                              onTap: () => _showPhotoSheet(hasPhoto),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$phone',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 13,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---- Account ----
                      const _SectionTitle('Account'),
                      _Section(
                        children: [
                          _Tile(
                            icon: Icons.person_outline_rounded,
                            title: 'Full name',
                            subtitle: name,
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: AppColors.primary,
                            ),
                            onTap: () => _editName(name),
                          ),
                          _Tile(
                            icon: Icons.phone_android_rounded,
                            title: 'Mobile number',
                            subtitle: '$phone',
                            trailing: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: AppColors.textGrey,
                            ),
                            onTap: () => _snack(
                              'Phone number cannot be changed after verification',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Preferences ----
                      const _SectionTitle('Preferences'),
                      _Section(
                        children: [
                          _Tile(
                            icon: Icons.notifications_active_outlined,
                            title: 'Queue alerts',
                            subtitle: 'Notify me when my turn is near',
                            trailing: Switch(
                              value: _alerts,
                              onChanged: _setAlerts,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.primary,
                            ),
                            onTap: () => _setAlerts(!_alerts),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---- Support ----
                      const _SectionTitle('Support'),
                      _Section(
                        children: [
                          _Tile(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TermsConditionsScreen(),
                              ),
                            ),
                          ),
                          _Tile(
                            icon: Icons.help_outline_rounded,
                            title: 'Help & Support',
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                title: const Text('Help & Support'),
                                content: const Text(
                                  'Need help with your token or queue? Please contact the hospital reception desk.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      // ---- Logout ----
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text('Log out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: .4),
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'MediQueue v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
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

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: AppColors.cardBorder),
  boxShadow: [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: .06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ],
);

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoBase64;
  final bool busy;
  final VoidCallback onTap;

  const _Avatar({
    required this.name,
    required this.photoBase64,
    required this.busy,
    required this.onTap,
  });

  String get _initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          children: [
            Container(
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: photoBase64 != null
                      ? Image.memory(
                          base64Decode(photoBase64!),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          color: AppColors.primary.withValues(alpha: .1),
                          alignment: Alignment.center,
                          child: Text(
                            _initial,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (busy)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .7),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: AppColors.textGrey,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(
          Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppColors.cardBorder,
          ),
        );
      }
    }
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: color ?? AppColors.textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _EditNameSheet extends StatefulWidget {
  final String initial;
  const _EditNameSheet({required this.initial});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = _ctrl.text.trim();
    if (v.length < 2) {
      setState(() => _error = 'Please enter at least 2 characters');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Edit name',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: 'Your full name',
                  errorText: _error,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PremiumButton(label: 'Save', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}