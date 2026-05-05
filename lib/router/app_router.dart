import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/main/main_shell.dart';
import '../screens/friends/friend_detail_screen.dart';
import '../screens/friends/qr_scanner_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/expense/choose_people_screen.dart';
import '../screens/expense/camera_screen.dart';
import '../screens/expense/review_items_screen.dart';
import '../screens/expense/assign_items_screen.dart';
import '../screens/expense/split_summary_screen.dart';
import '../screens/expense/expense_detail_screen.dart';
import '../screens/settle/settle_up_screen.dart';
import '../models/models.dart';
import '../screens/auth/auth_wrapper.dart';

class AppRoutes {
  AppRoutes._();
  static const root = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const main = '/main';
  static const qrScanner = '/qr-scanner';
  static const createGroup = '/create-group';
  static const friendDetail = '/friend-detail';
  static const groupDetail = '/group-detail';
  static const choosePeople = '/expense/choose-people';
  static const camera = '/expense/camera';
  static const reviewItems = '/expense/review-items';
  static const assignItems = '/expense/assign-items';
  static const splitSummary = '/expense/split-summary';
  static const settleUp = '/settle-up';
  static const expenseDetail = '/expense-detail';
  static const settlementDetail = '/settlement-detail';
  static const friends = '/friends';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return _fade(const AuthWrapper());

      case AppRoutes.login:
        return _fade(const LoginScreen());

      case AppRoutes.signup:
        return _slide(const SignupScreen());

      case AppRoutes.main:
        // Accept initialIndex for the Bottom Navigation bar (0 = Friends, 1 = Groups, etc.)
        final initialIndex = settings.arguments as int? ?? 0;
        return _fade(MainShell(initialIndex: initialIndex));

      case AppRoutes.qrScanner:
        return _slide(const QRScannerScreen());

      case AppRoutes.createGroup:
        return _slide(const CreateGroupScreen());

      case AppRoutes.friendDetail:
        final friend = settings.arguments as Friend;
        return _slide(FriendDetailScreen(friend: friend));

      case AppRoutes.groupDetail:
        // FIX: Now accepts String groupId for the "Source of Truth" refactor
        final groupId = settings.arguments as String;
        return _slide(GroupDetailScreen(groupId: groupId));

      case AppRoutes.choosePeople:
        final args = settings.arguments as Map<String, dynamic>?;
        final groupId = args?['groupId'] as String?;
        final isManual = args?['isManual'] as bool? ?? false;
        return _slide(ChoosePeopleScreen(groupId: groupId, isManual: isManual));

      case AppRoutes.camera:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(CameraScreen(
          selectedFriends: args['friends'] as List<Friend>,
          groupId: args['groupId'] as String?,
        ));

      case AppRoutes.reviewItems:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ReviewItemsScreen(
          items: args['items'] as List<ReceiptItem>,
          friends: args['friends'] as List<Friend>,
          groupId: args['groupId'] as String?,
        ));

      case AppRoutes.assignItems:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(AssignItemsScreen(
          items: args['items'] as List<ReceiptItem>,
          friends: args['friends'] as List<Friend>,
          groupId: args['groupId'] as String?,
        ));

      case AppRoutes.splitSummary:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(SplitSummaryScreen(
          items: args['items'] as List<ReceiptItem>,
          friends: args['friends'] as List<Friend>,
          paidBy: args['paidBy'] as Friend,
          groupId: args['groupId'] as String?,
        ));

      case AppRoutes.settleUp:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(SettleUpScreen(
          groupId: args['groupId'] as String? ?? '',
          targetFriendId: args['targetFriendId'] as String? ?? '',
          friendName: args['friendName'] as String? ?? 'Friend',
          amountOwed: args['amount'] as double? ?? 0.0,
        ));

      case AppRoutes.expenseDetail:
        final expenseId = settings.arguments as String;
        return _slide(ExpenseDetailScreen(expenseId: expenseId));

      default:
        return _fade(_NotFoundScreen(route: settings.name ?? '?'));
    }
  }

  static String get initialRoute {
    return AppRoutes.root;
  }

  static PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      );

  static PageRoute<T> _slide<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) {
          final tween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: anim.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      );
}

class _NotFoundScreen extends StatelessWidget {
  final String route;
  const _NotFoundScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('404', style: TextStyle(fontSize: 48)),
            Text('Route not found: $route'),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.main),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
