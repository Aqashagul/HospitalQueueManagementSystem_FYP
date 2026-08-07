import 'package:flutter/material.dart';
import 'package:queue_management_system/data/nav_items_data.dart';
import 'package:queue_management_system/models/nav_items_model.dart';
import 'package:queue_management_system/widgets/sidebar_item.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const Sidebar({super.key, 
   required this.selectedIndex,
   required this.onItemSelected,});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
    
  int? hoveredIndex;  
  bool isLogoutHovered = false;

  void _handleLogout(BuildContext context) {
  // Abhi ke liye simple example — baad mein Firebase/auth logic yahan aayega
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Logout"),
      content: const Text("Do you want to Logout?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // yahan actual logout: auth.signOut() ya navigate to login screen
          },
          child: const Text("Logout"),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Container(
      width: 85,
      color: const Color(0xFF1A1A1A), //dark bg
      child: Column(
        children: [
          Row(
            children: [
              //Logo
              //Text
            ],
          ),

          Expanded(
            child: ListView.builder(
              itemCount: navItems.length, // total kitne items hain
              itemBuilder: (context, index) {
                final item = navItems[index];

                return  MouseRegion(
    onEnter: (_) {
      setState(() {
        hoveredIndex = index;
      });
    },
    onExit: (_) {
      setState(() {
        hoveredIndex = null;
      });
    },
    child:  SidebarItem(
                  item: item,
                  isSelected: widget.selectedIndex == index,
                  isHovered: hoveredIndex == index,
                  onTap: () {
                    setState(() {
                      widget.onItemSelected(index);
                    });
                  },
                )
                );
              },
            ),
            
          ),

         const Divider(
  color: Color.fromARGB(255, 238, 226, 226),
  thickness: 1,
  height: 20,
),

          // Logout item — neeche fixed rahega, list ke saath scroll nahi hoga
MouseRegion(
  onEnter: (_) => setState(() => isLogoutHovered = true),
  onExit: (_) => setState(() => isLogoutHovered = false),
  child: SidebarItem(
    item: NavItem(
      title: "Logout",
      icon: Icons.logout_outlined,
      pageBuilder: () => const SizedBox(), // logout ka page nahi hota, dummy de diya
    ),
    isSelected: false,          // logout kabhi selected/highlighted nahi hota
    isHovered: isLogoutHovered,
    onTap: () {
      // yahan tumhara logout logic aayega
      _handleLogout(context);
    },
  ),
),
        ],
      ),
    );
  }
}
