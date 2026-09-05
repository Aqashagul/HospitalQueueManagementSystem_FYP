import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../models/department.dart';
import '../models/doctor.dart';
import 'doctor_detail_screen.dart';

class DoctorListScreen extends StatefulWidget {
  final Department department;
  const DoctorListScreen({super.key, required this.department});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Doctor> _allDoctors;
  late List<Doctor> _filteredDoctors;

  @override
  void initState() {
    super.initState();
    _allDoctors = sampleDoctors
        .where((doc) => doc.departmentId == widget.department.id)
        .toList();
    _filteredDoctors = _allDoctors;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredDoctors = _allDoctors
          .where(
            (doc) =>
                doc.name.toLowerCase().contains(query.trim().toLowerCase()),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Department name badge
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color.fromARGB(255, 106, 183, 183).withValues(alpha: 0.80),
                          const Color.fromARGB(255, 121, 170, 173).withValues(alpha: 0.80),
                          const Color.fromARGB(255, 199, 141, 230).withValues(alpha: 0.80),
                          
                          
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            widget.department.iconPath,
                            //color: Colors.white,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint(
                                'Department icon load failed: ${widget.department.iconPath}',
                              );
                              return const Icon(
                                Icons.local_hospital_rounded,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                            
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEPARTMENT',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGrey,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.department.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right side 
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'Available Doctors',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

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
                        hintText: 'Search doctor...',
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
                  const SizedBox(height: 18),

                  Expanded(
                    child: _filteredDoctors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 48,
                                  color: AppColors.textGrey.withValues(
                                    alpha: .5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No doctor found',
                                  style: TextStyle(color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _filteredDoctors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final doctor = _filteredDoctors[index];
                              return _DoctorCard(
                                doctor: doctor,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DoctorDetailScreen(doctor: doctor),
                                    ),
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
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {


    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: doctor.isActive ? onTap : null,
       child: Opacity(
        opacity: doctor.isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: doctor.isActive ? Colors.white : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: doctor.isActive ? AppColors.cardBorder : const Color(0xFFE0E0E0),
          ),
          boxShadow: doctor.isActive
          ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
          :[],
        ),
        child: Row(
          children: [
            // Circular doctor image with gradient ring
            Stack(
              clipBehavior: Clip.none,
              children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:  LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd])
                  
                ),
              padding: const EdgeInsets.all(2.5),
              child: ClipOval(
                child: Container(
                  color: Colors.white,
                  child: Image.asset(
                    doctor.imagePath,
                    fit: BoxFit.cover,
                    // if image fails
                    errorBuilder: (context, error, stackTrace) => 
                    const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),

             Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: doctor.isActive ? Colors.green : Colors.red,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
             ),
              ],
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                       color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    doctor.specialization,
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),

                  if(!doctor.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                     color: Colors.red.withValues(alpha: .08),
                
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: const Text(
                       'Unavailable',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red),
                    ),
                  )
                  else 
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20)
                  ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${doctor.currentQueueLength} in queue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
             Icons.chevron_right_rounded,
            color: doctor.isActive ? AppColors.textGrey : AppColors.textGrey.withValues(alpha: .4),
            ),
          ],
        ),
      ),
       ),
    );
  }
}
