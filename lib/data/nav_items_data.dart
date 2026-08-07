import 'package:flutter/material.dart';
import 'package:queue_management_system/models/nav_items_model.dart';
import 'package:queue_management_system/screens/dashboard_page.dart';
import 'package:queue_management_system/screens/data_insights_page.dart';
import 'package:queue_management_system/screens/department_management_page.dart';
import 'package:queue_management_system/screens/doctor_management_page.dart';
import 'package:queue_management_system/screens/patient_management_page.dart';
import 'package:queue_management_system/screens/queue_management_page.dart';
import 'package:queue_management_system/screens/settings_page.dart';

final List<NavItem> navItems = [
  NavItem(
    title: "Overview",
    icon: Icons.home_work_outlined,
    pageBuilder: () => const DashboardPage(),
  ),

  NavItem(
    title: "Queue",
    icon: Icons.playlist_add_check_circle_outlined,
    pageBuilder: () => const QueueManagementPage(),
  ),

  NavItem(
    title: "Patients",
    icon: Icons.people_alt_outlined,
    pageBuilder: () => const PatientManagementPage(),
  ),

  NavItem(
    title: "Doctors",
    icon: Icons.medical_services_outlined,
    pageBuilder: () => const DoctorManagementPage(),
  ),

  NavItem(
    title: "Departments",
    icon: Icons.apartment_outlined,
    pageBuilder: () => const DepartmentManagementPage(),
  ),

  NavItem(
    title: "Reports",
    icon: Icons.insights_outlined,
    pageBuilder: () => const DataInsightsPage(),
  ),

  NavItem(
    title: "Settings",
    icon: Icons.settings_outlined,
    pageBuilder: () => const SettingsPage(),
  ),

];
