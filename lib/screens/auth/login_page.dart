import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/screens/layout/app_shell.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Hardcoded credentials used for now instead of real authentication.
  // Replace with an actual auth call (API/Firebase/etc.) later.
  static const String _fakeEmail = "admin@gmail.com";
  static const String _fakePassword = "admin123";

  static const List<Color> _brandGradient = [
    Color(0xFFBCA8E8),
    Color(0xFFA25AE6),
  ];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoggingIn = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Checks the entered email/password against the hardcoded fake
  // credentials. Only navigates to AppShell if they match; otherwise
  // shows an inline error message.
  Future<void> _handleLogin() async {
    final enteredEmail = emailController.text.trim();
    final enteredPassword = passwordController.text.trim();

    // Check for empty fields first — no need to show a spinner for a
    // simple validation error.
    if (enteredEmail.isEmpty || enteredPassword.isEmpty) {
      setState(() {
        errorMessage = "Input fields cannot be empty";
      });
      return;
    }

    setState(() {
      isLoggingIn = true;
      errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (enteredEmail == _fakeEmail && enteredPassword == _fakePassword) {
      setState(() => isLoggingIn = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    } else {
      setState(() {
        isLoggingIn = false;
        errorMessage = "Invalid email or password";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // Original desktop/web/laptop layout — unchanged.
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _buildAnimationPanel(),
        ),
        Expanded(
          flex: 7,
          child: _buildFormPanel(),
        ),
      ],
    );
  }

  // LEFT PANEL: gradient background with a Lottie animation, falling
  // back to a text message if the asset fails to load.
  Widget _buildAnimationPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              "assets/images/login_animation.json",
              height: 460,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      "Animation failed to load",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // RIGHT PANEL: logo, heading, and the email/password login form.
  Widget _buildFormPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 88, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  "assets/images/app_logo.png",
                  width: 60,
                  height: 60,
                ),
                const SizedBox(height: 25),
                Text(
                  "Welcome Back",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Login to access your dashboard",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildFieldLabel("Email"),
          const SizedBox(height: 6),
          _buildEmailField(),
          const SizedBox(height: 18),

          _buildFieldLabel("Password"),
          const SizedBox(height: 6),
          _buildPasswordField(),

          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            _buildErrorText(),
          ],

          const SizedBox(height: 28),
          _buildLoginButton(),
        ],
      ),
    );
  }


  Widget _buildMobileLayout() {
    return Stack(
      children: [
        const Positioned.fill(child: BgBoxes()), // same decorative circles as the other pages
        SafeArea(
          child: LayoutBuilder( // NEW — lets us center the content vertically
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center( // centers everything vertically
                    child: Column(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Image.asset(
                          "assets/images/app_logo.png",
                          width: 60,
                          height: 60,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Welcome Back",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Login to access your dashboard",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 28),

                        RoundedCard(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("Email"),
                              const SizedBox(height: 6),
                              _buildEmailField(),
                              const SizedBox(height: 16),

                              _buildFieldLabel("Password"),
                              const SizedBox(height: 6),
                              _buildPasswordField(),

                              if (errorMessage != null) ...[
                                const SizedBox(height: 10),
                                _buildErrorText(),
                              ],

                           const SizedBox(height: 24),
_buildLoginButton(),
const SizedBox(height: 12),
Center(
  child: Text(
    "For an enhanced experience, desktop access is recommended.",
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 11,
      color: Colors.grey,
    ),
  ),
),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700));
  }

  Widget _buildEmailField() {
    return TextField(
      controller: emailController,
      decoration: InputDecoration(
        hintText: "example@gmail.com",
        filled: true,
        fillColor: const Color.fromARGB(255, 255, 255, 255),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.hover,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 225, 225, 225),
            width: 1.5,
          ),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      decoration: InputDecoration(
        hintText: "password",
        filled: true,
        fillColor: const Color.fromARGB(255, 255, 255, 255),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.hover,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 225, 225, 225),
            width: 1.5,
          ),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey.shade500,
          ),
          onPressed: () {
            setState(() => obscurePassword = !obscurePassword);
          },
        ),
      ),
    );
  }

  Widget _buildErrorText() {
    return Text(
      errorMessage!,
      style: const TextStyle(fontSize: 13, color: Colors.red),
    );
  }

  // Gradient login button — shows a spinner while _handleLogin runs
  // and is disabled during that time to prevent double submits.
  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: ElevatedButton(
        onPressed: isLoggingIn ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0x00000000),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoggingIn
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("Login", style: TextStyle(fontSize: 15)),
      ),
    );
  }
}