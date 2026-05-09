import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Standard app scaffold — Canvas White background, clean AppBar with no
/// elevation or shadow, Midnight Ink text and icons.
class AppScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep status bar icons readable against the white / dark AppBar
    final systemOverlay = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
        backgroundColor:
            backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          // Theme already sets elevation 0 and correct colors; this ensures
          // no tint is applied even when content scrolls beneath the bar.
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          foregroundColor: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
