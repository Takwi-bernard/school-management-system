import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/landing/landing_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/auth/parent_sign_up_page.dart';
import '../features/auth/teacher_sign_up_page.dart';
import '../features/auth/auth_gate.dart';
import '../features/teacher/teacher_home.dart';
import '../features/parent/parent_home.dart';
import '../features/parent/parent_enrollment.dart';
import '../features/parent/parent_fees.dart';
import '../features/parent/parent_report_card.dart';
import '../features/parent/parent_profile.dart';
import '../features/parent/parent_models.dart';
/// FIX: default GoRouter navigation is an abrupt cut with no
/// transition at all. This gives every route the same soft
/// fade + gentle upward slide - noticeably smoother/more "alive"
/// without being slow (~380ms), and consistent everywhere rather
/// than each page inventing its own.
CustomTransitionPage<void> _page(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: 'landing', pageBuilder: (c, s) => _page(const LandingPage(), s)),
    GoRoute(path: '/sign-in', name: 'sign-in', pageBuilder: (c, s) => _page(const SignInPage(), s)),
    GoRoute(path: '/sign-up', name: 'sign-up', pageBuilder: (c, s) => _page(const SignUpPage(), s)),
    GoRoute(
      path: '/sign-up/parent',
      name: 'sign-up-parent',
      pageBuilder: (c, s) => _page(const ParentSignUpPage(), s),
    ),
    GoRoute(
      path: '/sign-up/teacher',
      name: 'sign-up-teacher',
      pageBuilder: (c, s) => _page(const TeacherSignUpPage(), s),
    ),
    GoRoute(
      path: '/parent',
      pageBuilder: (c, s) => _page(const ParentHome(), s),
    ),
    GoRoute(
  path: '/parent',
  pageBuilder: (c, s) => _page(const ParentHome(), s),
  routes: [
    GoRoute(
      path: 'enroll',
      pageBuilder: (c, s) => _page(EnrollChildPage(schoolId: s.extra as String), s),
    ),
    GoRoute(
      path: 'fees',
      pageBuilder: (c, s) => _page(ChildFeesPage(child: s.extra as EnrolledChild), s),
    ),
    GoRoute(
      path: 'report-card',
      pageBuilder: (c, s) => _page(ReportCardPage(child: s.extra as EnrolledChild), s),
    ),
    GoRoute(
      path: 'review',
      pageBuilder: (c, s) => _page(ReviewChildPage(child: s.extra as EnrolledChild), s),
    ),
    GoRoute(
      path: 'profile',
      pageBuilder: (c, s) => _page(const ParentProfilePage(), s),
    ),
    GoRoute(
      path: 'payment',
      pageBuilder: (c, s) {
        final args = s.extra as Map<String, dynamic>;
        return _page(
          MobileMoneyPaymentPage(
            child: args['child'] as EnrolledChild?,
            admissionRequestId: args['admissionRequestId'] as String?,
            landing: args['landing'],
            amount: args['amount'] as double,
            paymentPurpose: args['paymentPurpose'] as String,
          ),
          s,
        );
      },
    ),
  ],
),
    GoRoute(
      path: '/teacher',
      pageBuilder: (c, s) => _page(const TeacherHome(), s),
    ),
    GoRoute(
      path: '/principal',
      pageBuilder: (c, s) =>
          _page(const RoleGate(requiredRole: 'principal', label: 'Principal'), s),
    ),
    GoRoute(
      path: '/secretary',
      pageBuilder: (c, s) =>
          _page(const RoleGate(requiredRole: 'secretary', label: 'Secretary'), s),
    ),
    GoRoute(
      path: '/proprietor',
      pageBuilder: (c, s) =>
          _page(const RoleGate(requiredRole: 'proprietor', label: 'Proprietor'), s),
    ),
  ],
);

