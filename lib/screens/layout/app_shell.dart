import 'package:flutter/material.dart';
import 'package:queue_management_system/data/nav_items_data.dart';
import 'package:queue_management_system/widgets/sidebar.dart';


class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Index of the currently active sidebar item / page.
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                // Builds and shows the page for the currently selected nav item.
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