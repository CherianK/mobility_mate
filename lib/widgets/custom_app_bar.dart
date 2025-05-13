import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: leading,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      actions: [
        // Theme toggle button
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () {
            final themeProvider = context.read<ThemeProvider>();
            final newMode = themeProvider.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
            themeProvider.setThemeMode(newMode);
          },
          tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        ),
        // Additional actions
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 