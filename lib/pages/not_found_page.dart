import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_state_views.dart';
import '../core/widgets/failure_messages.dart';
import '../navigation/route_names.dart';

/// Layar 404. Penting di web, tempat pengguna dapat mengetik alamat sendiri.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.notFoundPageTitle)),
      body: AppEmptyState(
        icon: Icons.explore_off_outlined,
        title: t.notFoundPageTitle,
        message: t.notFoundPageMessage,
        actionLabel: t.navHome,
        onAction: () => context.go(Routes.splash),
      ),
    );
  }
}
