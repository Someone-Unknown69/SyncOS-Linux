import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/pages/components/header.dart';
import 'package:laptop_controller/theme/app_theme.dart';

class BasePage extends ConsumerWidget {
  final String title;
  final bool showBackButton;
  final List<Widget> children;
  final Widget? floatingActionButton;

  const BasePage({
    super.key,
    required this.title,
    required this.children,
    this.showBackButton = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: floatingActionButton,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title, showBackButton: showBackButton),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}