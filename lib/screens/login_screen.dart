import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  // For web admin login
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  Color get _primary => const Color(0xFF0EA5E9);
  Color get _accent => const Color(0xFF22D3EE);
  Color get _bgLight => const Color(0xFFF4F7FB);
  Color get _textPrimary => const Color(0xFF0F172A);

  void _showStatus(String message, Color color, {IconData? icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<bool> _isAdmin(User user) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return (snap.data()?['admin'] ?? false) == true;
  }

  // GOOGLE SIGN-IN (mobile / non-web)
  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null && mounted) {
        _showStatus(
          'Signed in as ${user.email}',
          Colors.green.shade600,
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showStatus(
          'Sign-in failed: $e',
          Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // EMAIL/PASSWORD ADMIN SIGN-IN (web)
  Future<void> _handleWebAdminSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showStatus(
        'Enter email and password',
        Colors.red.shade600,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user == null || !(await _isAdmin(user))) {
        await FirebaseAuth.instance.signOut();
        _showStatus(
          'Access restricted to admin accounts',
          Colors.red.shade600,
          icon: Icons.lock_outline,
        );
        return;
      }

      if (mounted) {
        _showStatus(
          'Admin signed in: ${user.email}',
          Colors.green.shade600,
          icon: Icons.check_circle_rounded,
        );
        // Navigation is still handled by your auth stream in main.dart
      }
    } on FirebaseAuthException catch (e) {
      _showStatus(
        e.message ?? 'Sign-in failed',
        Colors.red.shade600,
        icon: Icons.error_outline,
      );
    } catch (e) {
      _showStatus(
        'Sign-in failed: $e',
        Colors.red.shade600,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgLight, const Color(0xFFEAF3FF), Colors.white],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(
              painter: _MapOverlayPainter(color: Colors.black.withAlpha(10)),
              size: Size.infinite,
            ),
            _BlurSpot(
              size: 240,
              color: _accent.withAlpha(46),
              alignment: const Alignment(-1.0, -0.8),
            ),
            _BlurSpot(
              size: 200,
              color: Colors.deepOrangeAccent.withAlpha(31),
              alignment: const Alignment(1.0, 0.9),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 30),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFC8D9E6).withAlpha(170),
                                const Color(0xFFC8D9E6).withAlpha(110),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color:
                                  const Color(0xFFC8D9E6).withAlpha(140),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withAlpha(12),
                                blurRadius: 26,
                                spreadRadius: 3,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: Colors.white.withAlpha(35),
                                blurRadius: 0,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primary.withAlpha(89),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [_primary, _accent],
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(120),
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      height: 110,
                                      width: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'SnapFind',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isWeb
                                    ? 'Admin portal – campus moderation'
                                    : 'See it, Snap it, Find it.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          _textPrimary.withAlpha(189),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                              const SizedBox(height: 26),

                              // DIFFERENT CONTENT FOR WEB vs MOBILE
                              if (isWeb) ...[
                                // Email field
                                TextField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Admin email',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Password field
                                TextField(
                                  controller: _passCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF111827),
                                        Color(0xFF1F2937)
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(70),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : _handleWebAdminSignIn,
                                    style: FilledButton.styleFrom(
                                      minimumSize:
                                          const Size.fromHeight(52),
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<
                                                      Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.lock_open),
                                    label: Text(_loading
                                        ? 'Signing you in...'
                                        : 'Admin sign in'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Opacity(
                                  opacity: 0.8,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings_rounded,
                                        color: _textPrimary
                                            .withOpacity(0.8),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Restricted to authorised admins',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _textPrimary
                                                  .withAlpha(184),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // ORIGINAL GOOGLE SIGN-IN BUTTON (mobile)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF111827),
                                        Color(0xFF1F2937)
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(70),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : _handleGoogleSignIn,
                                    style: FilledButton.styleFrom(
                                      minimumSize:
                                          const Size.fromHeight(56),
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 18),
                                    ),
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<
                                                      Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.login_rounded),
                                    label: Text(_loading
                                        ? 'Signing you in...'
                                        : 'Continue with Google'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Opacity(
                                  opacity: 0.8,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: _textPrimary
                                            .withOpacity(0.8),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Secure sign-in • Your email stays private',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _textPrimary
                                                  .withAlpha(184),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------- rest of your painter / blur widgets stay the same -------

class _MapOverlayPainter extends CustomPainter {
  _MapOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double gap = 80;
    for (double x = -40; x < size.width + 40; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + 40, size.height), paint);
      canvas.drawLine(
          Offset(x + gap / 2, 0), Offset(x + gap / 2 - 40, size.height), paint);
    }

    for (double y = 0; y < size.height + 80; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 30), paint);
      canvas.drawLine(
          Offset(0, y + gap / 2), Offset(size.width, y + gap / 2 - 30), paint);
    }

    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (double x = 20; x < size.width; x += gap) {
      for (double y = 30; y < size.height; y += gap) {
        canvas.drawCircle(
            Offset(x + (y % 2 == 0 ? 10 : -10), y), 3, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapOverlayPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BlurSpot extends StatelessWidget {
  const _BlurSpot({
    required this.size,
    required this.color,
    required this.alignment,
  });

  final double size;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 50,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}