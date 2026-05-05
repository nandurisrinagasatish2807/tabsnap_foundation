import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final handle = _handleController.text.trim().toLowerCase();

    final success = await AuthService().setupUserProfile(
      uid: currentUser.uid,
      fullName: _nameController.text.trim(),
      handle: handle,
    );

    if (mounted) {
      if (success) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.root, (route) => false);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'That handle is already taken. Please try another.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set up your identity',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your friends will use this to find you and split bills.',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                const Text('Full Name', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'John Doe',
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Please enter your full name'
                      : null,
                ),
                const SizedBox(height: 24),
                const Text('Username Handle', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _handleController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'johndoe',
                    prefixText: '@',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Handle is required';
                    }
                    if (v.trim().contains(' ')) {
                      return 'Handle cannot contain spaces';
                    }
                    if (v.trim().length < 3) {
                      return 'Handle must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Complete Setup'),
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
