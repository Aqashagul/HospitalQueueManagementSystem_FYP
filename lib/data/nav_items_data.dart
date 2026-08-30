import 'package:flutter/material.dart';
import 'package:queue_management_system/models/nav_items_model.dart';
import 'package:queue_management_system/screens/dashboard_page.dart';
import 'package:queue_management_system/screens/reports_page.dart';
import 'package:queue_management_system/screens/department_management_page.dart';
import 'package:queue_management_system/screens/doctor_management_page.dart';
import 'package:queue_management_system/screens/patient_management_page.dart';
import 'package:queue_management_system/screens/queue_management_page.dart';


final List<NavItem> navItems = [
  NavItem(
    title: "Dashboard",
    icon: Icons.dashboard_outlined,
    pageBuilder: () => const DashboardPage(),
  ),


 NavItem(
    title: "Department Management",
    icon: Icons.apartment_outlined,
    pageBuilder: () => const DepartmentManagementPage()
  ),


 NavItem(
    title: "Doctor Management",
    icon: Icons.medical_services_outlined,
    pageBuilder: () => const DoctorManagementPage(),
  ),


NavItem(
    title: "Patient Management",
    icon: Icons.people_alt_outlined,
    pageBuilder: () => const PatientManagementPage(),
  ),


  NavItem(
    title: "Queue Management",
    icon: Icons.playlist_add_check_circle_outlined,
    pageBuilder: () => const QueueManagementPage(),
  ),

  NavItem(
    title: "Reports & Analytics",
    icon: Icons.insights_outlined,
    pageBuilder: () => const ReportsPage(),
  ),

 

];
