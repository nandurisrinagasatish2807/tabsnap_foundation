import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/models.dart';
import 'onboarding_screen.dart';
import 'profile_setup_screen.dart';
import '../main/main_shell.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const OnboardingScreen();
        }

        // User is authenticated
        return FutureBuilder<void>(
          future: AuthService().syncUserToFirestore(user),
          builder: (context, syncSnapshot) {
            if (syncSnapshot.connectionState == ConnectionState.waiting) {
               return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final userModel = UserModel.fromFirestore(userSnapshot.data!);

                if (userModel.fullName.isEmpty || userModel.handle.isEmpty) {
                  return const ProfileSetupScreen();
                }

                return const MainShell(); // Everything is set up
              },
            );
          },
        );
      },
    );
  }
}
