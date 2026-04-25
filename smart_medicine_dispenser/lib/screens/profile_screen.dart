// lib/screens/profile_screen.dart
// User profile screen — shows personal details, medications, and account actions

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final UserModel? userModel;

  const ProfileScreen({super.key, required this.user, this.userModel});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isEditing = false;

  // Controllers for the edit form
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _ageCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userModel?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.userModel?.phone ?? '');
    _ageCtrl = TextEditingController(text: '${widget.userModel?.age ?? ''}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await _firestoreService.updateUser(widget.user.uid, {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text) ?? widget.userModel?.age ?? 0,
    });
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.signOut();
      // StreamBuilder in main.dart automatically navigates to LoginScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use real-time stream so profile updates reflect instantly
    return StreamBuilder<UserModel?>(
      stream: _firestoreService.getUserStream(widget.user.uid),
      builder: (context, snapshot) {
        final user = snapshot.data ?? widget.userModel;

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // Pre-fill form with current values
                    _nameCtrl.text = user?.name ?? '';
                    _phoneCtrl.text = user?.phone ?? '';
                    _ageCtrl.text = '${user?.age ?? ''}';
                    setState(() => _isEditing = true);
                  },
                )
              else ...[
                TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: _saveProfile,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── AVATAR & NAME ─────────────────────────────────────
                _buildAvatarSection(user),
                const SizedBox(height: 20),

                // ── PERSONAL INFO ─────────────────────────────────────
                _SectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outlined,
                  children: _isEditing
                      ? [
                          _editField(_nameCtrl, 'Full Name', Icons.person),
                          const SizedBox(height: 12),
                          _editField(_phoneCtrl, 'Phone', Icons.phone,
                              type: TextInputType.phone),
                          const SizedBox(height: 12),
                          _editField(_ageCtrl, 'Age', Icons.cake,
                              type: TextInputType.number),
                        ]
                      : [
                          _InfoRow('Name', user?.name ?? '—', Icons.person),
                          _InfoRow('Email', user?.email ?? '—', Icons.email),
                          _InfoRow('Phone', user?.phone ?? '—', Icons.phone),
                          _InfoRow('Age', '${user?.age ?? '—'} years', Icons.cake),
                          _InfoRow('Blood Group', user?.bloodGroup ?? '—',
                              Icons.bloodtype),
                        ],
                ),
                const SizedBox(height: 16),

                // ── DEVICE INFO ────────────────────────────────────────
                _SectionCard(
                  title: 'Device Information',
                  icon: Icons.devices,
                  children: [
                    _InfoRow('Device ID',
                        user?.dispenserDeviceId ?? '—', Icons.device_hub),
                    _InfoRow('Account UID',
                        widget.user.uid.substring(0, 12) + '...', Icons.key),
                  ],
                ),
                const SizedBox(height: 16),

                // ── MEDICATIONS ────────────────────────────────────────
                if (user != null && user.medications.isNotEmpty)
                  _SectionCard(
                    title: 'Medications (${user.medications.length})',
                    icon: Icons.medication,
                    children: user.medications
                        .map((med) => _MedicationRow(med: med))
                        .toList(),
                  ),
                const SizedBox(height: 16),

                // ── ACCOUNT ACTIONS ────────────────────────────────────
                _SectionCard(
                  title: 'Account',
                  icon: Icons.settings,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline,
                          color: Color(0xFF1565C0)),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        await _authService
                            .resetPassword(widget.user.email ?? '');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Password reset email sent!')),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sign Out',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                      onTap: _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarSection(UserModel? user) {
    final initials = (user?.name ?? 'U')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join('');

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF1565C0),
          child: Text(
            initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user?.name ?? 'Loading...',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Blood Group: ${user?.bloodGroup ?? '—'}',
            style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

// ── SECTION CARD ───────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── INFO ROW ───────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── MEDICATION ROW ─────────────────────────────────────────────────────────
class _MedicationRow extends StatelessWidget {
  final Medication med;
  const _MedicationRow({required this.med});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication,
                color: Color(0xFF1565C0), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(med.dosage,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: med.times
                .map((t) => Text(t,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600)))
                .toList(),
          ),
        ],
      ),
    );
  }
}