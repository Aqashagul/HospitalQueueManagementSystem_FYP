import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/nav_items_data.dart';
import 'package:queue_management_system/widgets/sidebar.dart';


class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  static const double _mobileBreakpoint = 650;

  @override
  Widget build(BuildContext context) {
    final bool isMobile =
        MediaQuery.of(context).size.width < _mobileBreakpoint;

    void selectPage(int index) {
      setState(() => selectedIndex = index);
      if (isMobile) Navigator.of(context).pop(); 
    }

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
             centerTitle: false, 
          iconTheme: const IconThemeData(color: AppColors.primary),
          title: Text(
  navItems[selectedIndex].title,
  style: AppTypography.title,
),
        ),
        drawer: Drawer(
           width: 220,
  backgroundColor: AppColors.white,
          child: Sidebar(
            selectedIndex: selectedIndex,
            forceExpanded: true,
            onItemSelected: selectPage,
          ),
        ),
        body: navItems[selectedIndex].pageBuilder(),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: selectedIndex,
            onItemSelected: selectPage,
          ),
          Expanded(child: navItems[selectedIndex].pageBuilder()),
        ],
      ),
    );
  }
}