import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import 'register_screen.dart';
import 'officer_access_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberEmail = false;
  String? _errorMessage;
  List<String> _savedEmails = [];

  // Animation controllers for background
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  final List<FloatingBubble> _bubbles = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();

    // Background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Generate floating bubbles
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

  Future<void> _loadSavedEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emails = prefs.getStringList('saved_emails') ?? [];
      final remember = prefs.getBool('remember_email') ?? false;
      final lastEmail = prefs.getString('last_email') ?? '';

      setState(() {
        _savedEmails = emails;
        _rememberEmail = remember;
        if (remember && lastEmail.isNotEmpty) {
          _emailController.text = lastEmail;
        }
      });
    } catch (e) {
      print('Error loading saved emails: $e');
    }
  }

  Future<void> _saveEmail(String email) async {
    if (!_rememberEmail || email.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Add to saved emails list (max 5)
      if (!_savedEmails.contains(email)) {
        _savedEmails.insert(0, email);
        if (_savedEmails.length > 5) {
          _savedEmails = _savedEmails.sublist(0, 5);
        }
      } else {
        // Move to top if already exists
        _savedEmails.remove(email);
        _savedEmails.insert(0, email);
      }

      await prefs.setStringList('saved_emails', _savedEmails);
      await prefs.setString('last_email', email);
      await prefs.setBool('remember_email', true);
    } catch (e) {
      print('Error saving email: $e');
    }
  }

  Future<void> _clearSavedEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_emails');
      await prefs.remove('last_email');
      await prefs.setBool('remember_email', false);
      setState(() {
        _savedEmails = [];
        _rememberEmail = false;
      });
    } catch (e) {
      print('Error clearing emails: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save email if remember is enabled
      await _saveEmail(_emailController.text.trim());

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

  Future<void> _openOfficerAccess() async {
    final selectedEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const OfficerAccessScreen(
          allowAccountSelection: true,
        ),
      ),
    );
    if (selectedEmail != null && mounted) {
      setState(() => _emailController.text = selectedEmail);
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Account email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null) return;

    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset instructions were sent.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link could not be sent: $error')),
      );
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  RegentColors.dmBackground.withOpacity(0.9),
                  RegentColors.violet.withOpacity(0.2),
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with animation
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.05),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      RegentColors.violet,
                                      RegentColors.darkViolet,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          RegentColors.violet.withOpacity(0.4),
                                      blurRadius:
                                          20 + (_pulseController.value * 10),
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // App name
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              RegentColors.lightViolet,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Regent Connect',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Email field
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty ||
                                _savedEmails.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _savedEmails.where((email) {
                              return email.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  );
                            });
                          },
                          onSelected: (String selection) {
                            _emailController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            // Sync with our controller
                            controller.text = _emailController.text;
                            controller.addListener(() {
                              _emailController.text = controller.text;
                            });

                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.black87),
                              cursorColor: RegentColors.violet,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle:
                                    const TextStyle(color: Colors.black54),
                                floatingLabelStyle:
                                    const TextStyle(color: RegentColors.violet),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.email,
                                    color: RegentColors.violet),
                                border: const OutlineInputBorder(),
                                suffixIcon: _savedEmails.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.black54,
                                        ),
                                        onPressed: () {
                                          // Show dropdown
                                          focusNode.requestFocus();
                                        },
                                      )
                                    : null,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: MediaQuery.of(context).size.width - 48,
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final email = options.elementAt(index);
                                      return ListTile(
                                        leading:
                                            const Icon(Icons.email_outlined),
                                        title: Text(email),
                                        dense: true,
                                        onTap: () => onSelected(email),
                                        trailing: IconButton(
                                          icon:
                                              const Icon(Icons.close, size: 18),
                                          onPressed: () async {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            setState(() {
                                              _savedEmails.remove(email);
                                            });
                                            await prefs.setStringList(
                                                'saved_emails', _savedEmails);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.black87),
                          cursorColor: RegentColors.violet,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.black54),
                            floatingLabelStyle:
                                const TextStyle(color: RegentColors.violet),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon:
                                Icon(Icons.lock, color: RegentColors.violet),
                            border: const OutlineInputBorder(),
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
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showResetPasswordDialog,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(color: RegentColors.lightViolet),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RegentColors.violet,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: RegentColors.violet.withOpacity(0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        OutlinedButton.icon(
                          onPressed: _openOfficerAccess,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: RegentColors.lightViolet.withOpacity(0.8),
                            ),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text(
                            'Regent staff / officer access',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.3))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5)),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.3))),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen()),
                                );
                              },
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  color: RegentColors.lightViolet,
                                  fontWeight: FontWeight.bold,
                                ),
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
}

// Floating bubble class
class FloatingBubble {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  FloatingBubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Background painter
class BubbleBackgroundPainter extends CustomPainter {
  final List<FloatingBubble> bubbles;
  final double animation;

  BubbleBackgroundPainter({required this.bubbles, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      // Update position based on animation
      final y = (bubble.y + animation * bubble.speed) % 1.2 - 0.1;
      final x = bubble.x + sin(animation * 2 * pi + bubble.y * 10) * 0.02;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            RegentColors.violet.withOpacity(bubble.opacity),
            RegentColors.darkViolet.withOpacity(bubble.opacity * 0.5),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(x * size.width, y * size.height),
          radius: bubble.size,
        ));

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        bubble.size,
        paint,
      );
    }

    // Draw some connecting lines for extra effect
    final linePaint = Paint()
      ..color = RegentColors.violet.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < bubbles.length - 1; i++) {
      for (int j = i + 1; j < bubbles.length; j++) {
        final b1 = bubbles[i];
        final b2 = bubbles[j];
        final y1 = (b1.y + animation * b1.speed) % 1.2 - 0.1;
        final y2 = (b2.y + animation * b2.speed) % 1.2 - 0.1;

        final distance = sqrt(pow((b1.x - b2.x) * size.width, 2) +
            pow((y1 - y2) * size.height, 2));

        if (distance < 150) {
          canvas.drawLine(
            Offset(b1.x * size.width, y1 * size.height),
            Offset(b2.x * size.width, y2 * size.height),
            linePaint
              ..color =
                  RegentColors.violet.withOpacity(0.05 * (1 - distance / 150)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
