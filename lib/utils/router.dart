import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:split/screens/auth/login_screen.dart';
import 'package:split/screens/auth/signup_screen.dart';
import 'package:split/screens/dashboard/dashboard_screen.dart';
import 'package:split/screens/expenses/add_expense_screen.dart';
import 'package:split/screens/expenses/analytics_screen.dart';
import 'package:split/screens/expenses/settlement_screen.dart';
import 'package:split/screens/groups/create_group_screen.dart';
import 'package:split/screens/groups/group_details_screen.dart';
import 'package:split/screens/groups/groups_list_screen.dart';
import 'package:split/screens/meals/meal_settlement_screen.dart';
import 'package:split/screens/meals/meal_tracking_screen.dart';
import 'package:split/screens/meals/outside_meal_screen.dart';
import 'package:split/screens/profile/profile_screen.dart';
import 'package:split/widgets/bottom_nav_shell.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login' || 
                       state.matchedLocation == '/signup';
    
    if (user == null && !isLoggingIn) {
      return '/login';
    }
    
    if (user != null && isLoggingIn) {
      return '/';
    }
    
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNavShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              builder: (context, state) => const GroupsListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/create-group',
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: '/group/:groupId/settlement',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return SettlementScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId/analytics',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return AnalyticsScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId/outside-meals',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return OutsideMealScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId/meals',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MealTrackingScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId/meal-settlement',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MealSettlementScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId/add-expense',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return AddExpenseScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/group/:groupId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return GroupDetailsScreen(groupId: groupId);
      },
    ),
  ],
);
