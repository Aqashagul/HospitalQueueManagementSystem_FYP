import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final IconData icon;
  final Widget Function() pageBuilder;

  const NavItem({required this.title, required this.icon, required this.pageBuilder});
}
