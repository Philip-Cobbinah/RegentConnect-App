import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/programs_data.dart';
import '../../../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  FacultyData? selectedFaculty;
  ProgramData? selectedProgram;
  int? selectedLevel;
  String? selectedSession;

  final List<int> levels = [100, 200, 300, 400];
  final List<String> sessions = const [
    'Morning Session (Regular)',
    'Evening Session (Regular)',
    'Weekend Stream',
  ];

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  final List<FloatingBubble> _bubbles = [];

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final random = Random();
    for (int i = 0; i < 15; i++) {
      _bubbles.add(FloatingBubble(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 60 + 20,
        speed: random.nextDouble() * 0.5 + 0.2,
        opacity: random.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedFaculty == null ||
        selectedProgram == null ||
        selectedLevel == null ||
        selectedSession == null) {
      setState(() {
        _errorMessage =
            'Please select your faculty, program, level, and session';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _fullNameController.text.trim(),
        program: selectedProgram!.name,
        level: selectedLevel!,
        role: 'student',
        stream: selectedFaculty!.name,
        session: selectedSession!,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  RegentColors.dmBackground.withOpacity(0.9),
                  RegentColors.darkViolet.withOpacity(0.2),
                  RegentColors.dmBackground.withOpacity(0.95),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    RegentColors.violet,
                                    RegentColors.darkViolet
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: RegentColors.violet.withOpacity(0.4),
                                    blurRadius:
                                        20 + (_pulseController.value * 10),
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person_add,
                                  size: 48, color: Colors.white),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, RegentColors.lightViolet],
                        ).createShader(bounds),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join Regent Connect',
                        style: TextStyle(
                            fontSize: 14, color: Colors.white.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 30),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(_errorMessage!,
                                      style:
                                          const TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),

                      // Full Name
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        icon: Icons.person_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter your full name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter your email';
                          if (!value.contains('@'))
                            return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Faculty dropdown
                      _buildDropdown<FacultyData>(
                        label: 'Faculty',
                        icon: Icons.school_outlined,
                        value: selectedFaculty,
                        items: universityFaculties
                            .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedFaculty = value;
                            selectedProgram = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Program dropdown
                      if (selectedFaculty != null)
                        _buildDropdown<ProgramData>(
                          label: 'Program',
                          icon: Icons.book_outlined,
                          value: selectedProgram,
                          items: selectedFaculty!.programs
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedProgram = value),
                        ),
                      if (selectedFaculty != null) const SizedBox(height: 16),

                      // Level dropdown
                      _buildDropdown<int>(
                        label: 'Level',
                        icon: Icons.stairs_outlined,
                        value: selectedLevel,
                        items: levels
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text('Level $l'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedLevel = value),
                      ),
                      const SizedBox(height: 16),

                      // Study session dropdown
                      _buildDropdown<String>(
                        label: 'Study Session',
                        icon: Icons.schedule_outlined,
                        value: selectedSession,
                        items: sessions
                            .map((session) => DropdownMenuItem(
                                  value: session,
                                  child: Text(
                                    session,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedSession = value),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: RegentColors.violet,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter a password';
                          if (value.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: RegentColors.violet,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please confirm your password';
                          if (value != _passwordController.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RegentColors.violet,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: RegentColors.violet.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Create Account',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                  color: RegentColors.lightViolet,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return CustomPaint(
          painter: BubbleBackgroundPainter(
            bubbles: _bubbles,
            animation: _backgroundController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: RegentColors.violet),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: RegentColors.dmSurface.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RegentColors.violet.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RegentColors.violet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: RegentColors.dmSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RegentColors.violet.withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item.value,
                enabled: item.enabled,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  child: item.child,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  child: item.child,
                ),
              ),
            )
            .toList(),
        dropdownColor: RegentColors.dmSurface,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: RegentColors.violet),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: RegentColors.violet),
        menuMaxHeight: 340,
      ),
    );
  }
}
