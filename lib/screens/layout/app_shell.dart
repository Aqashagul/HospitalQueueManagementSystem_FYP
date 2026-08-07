import 'package:flutter/material.dart';
import 'package:queue_management_system/data/nav_items_data.dart';
import 'package:queue_management_system/widgets/sidebar.dart';
import 'package:queue_management_system/widgets/top_appbar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;   

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:  Column(
      children: [
        const TopAppbar(),

        Expanded(
         child: Row(
        children: [
          Sidebar(
            selectedIndex: selectedIndex,
            onItemSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
          ),
          Expanded(
            child: navItems[selectedIndex].pageBuilder(),
          ),
        ],
          ),
      ),
      ],
        ),
    );
  }
}