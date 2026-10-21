import 'package:flutter/material.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/department_model.dart';
import 'package:queue_management_system/widgets/loading_or_offline.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import 'doctor_list_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';

const bool _hideInactiveDepartments = true;

class DepartmentListScreen extends StatefulWidget {
  const DepartmentListScreen({super.key});

  @override
  State<DepartmentListScreen> createState() => _DepartmentListScreenState();
}

class _DepartmentListScreenState extends State<DepartmentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  void _onSearchChanged(String query) {
    setState(() => _query = query.trim().toLowerCase());
  }

  // Departments come live from Firestore
  List<Department> _visibleDepartments() {
    return AppdataStore().departments.where((dept) {
      if (_hideInactiveDepartments && dept.status.toLowerCase() != 'active') {
        return false;
      }
      return dept.name.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
        body: Stack(
          children: [
            const BackgroundBlobs(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Select Department',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        NotificationBell(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a department to see available doctors',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search department...',
                          hintStyle: TextStyle(
                            color: AppColors.textGrey.withValues(alpha: .7),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textGrey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Department grid
                    Expanded(
                      child: ListenableBuilder(
                        listenable: AppdataStore(),
                        builder: (context, _) {
                          if (!AppdataStore().doctorsLoaded) {
                            return const LoadingOrOffline(
                              message: "Loading doctors...",
                            );
                          }
                          final departments = _visibleDepartments();

                          if (departments.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: AppColors.textGrey.withValues(
                                      alpha: .5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No department found',
                                    style: TextStyle(color: AppColors.textGrey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: departments.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.05,
                                ),
                            itemBuilder: (context, index) {
                              final dept = departments[index];
                              return _DepartmentCard(
                                department: dept,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DoctorListScreen(department: dept),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final Department department;
  final VoidCallback onTap;
  const _DepartmentCard({required this.department, required this.onTap});

  // Shown when the admin has not added a picture for this department: the
  // department's initials (same idea as the admin dashboard).
  String get _initials {
    final words = department.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // The picture the admin uploaded for this department, if any.
    final photo = department.photoBytes;
    final bool hasPhoto = photo != null && photo.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    AppColors.gradientStart.withValues(alpha: .9),
                    AppColors.gradientEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .25),
                    blurRadius: 8,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: hasPhoto
                  ? Image.memory(
                      photo,
                      width: 86,
                      height: 86,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Text(
                      _initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              department.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
