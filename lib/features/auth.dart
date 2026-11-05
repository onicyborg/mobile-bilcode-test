import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/common.dart';

class AuthScreen extends StatefulWidget {
  final String mode, email;
  const AuthScreen({super.key, required this.mode, this.email = ''});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      code = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, hidden = true;
  String? error, notice;
  int cooldown = 0;
  Timer? timer;
  bool get verify => widget.mode == 'verify';
  bool get register => widget.mode == 'register';
  @override
  void initState() {
    super.initState();
    email.text = widget.email;
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [email, password, name, code, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final app = context.read<AppState>();
      if (verify) {
        await app.api.json(
          '/auth/verify-email',
          method: 'POST',
          data: {'email': email.text.trim(), 'code': code.text},
          authenticated: false,
        );
        if (mounted) {
          showMessage(context, 'Email terverifikasi. Silakan masuk.');
          context.go('/login?email=${Uri.encodeComponent(email.text.trim())}');
        }
      } else if (register) {
        await app.api.json(
          '/auth/register',
          method: 'POST',
          data: {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'password': password.text,
          },
          authenticated: false,
        );
        if (mounted) {
          context.go('/verify?email=${Uri.encodeComponent(email.text.trim())}');
        }
      } else {
        await app.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiFailure && e.code == 'EMAIL_UNVERIFIED') {
          context.go('/verify?email=${Uri.encodeComponent(email.text.trim())}');
        } else {
          setState(() => error = friendlyError(e));
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'Masukkan alamat email yang valid.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await context.read<AppState>().api.json(
        '/auth/resend-verification',
        method: 'POST',
        data: {'email': email.text.trim()},
        authenticated: false,
      );
      if (!mounted) return;
      setState(() {
        notice = 'Jika email memenuhi syarat, kode baru akan dikirim. Periksa juga folder spam.';
        cooldown = 60;
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (cooldown <= 1) {
          t.cancel();
        }
        setState(() => cooldown--);
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AutofillGroup(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Brand(),
                        if (verify || register)
                          IconButton(
                            tooltip: 'Kembali ke login',
                            onPressed: busy ? null : () => context.go('/login'),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF233D2C)
                            : const Color(0xFFE8EFDE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        verify
                            ? Icons.mark_email_read_outlined
                            : register
                            ? Icons.person_add_alt_outlined
                            : Icons.eco_outlined,
                        color: c.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      verify
                          ? 'Verifikasi email'
                          : register
                          ? 'Mulai dari sekitar.'
                          : 'Lingkungan lebih baik,\nmulai dari kita.',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      verify
                          ? 'Masukkan kode 6 digit dari email. Kode berlaku selama 10 menit.'
                          : register
                          ? 'Buat akun untuk melaporkan sampah dan memantau penanganannya.'
                          : 'Masuk untuk melaporkan sampah dan mengikuti perkembangannya.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (register) ...[
                            TextFormField(
                              controller: name,
                              decoration: const InputDecoration(
                                labelText: 'Nama lengkap',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              maxLength: 100,
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Masukkan nama lengkap.'
                                  : null,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: email,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            validator: (v) =>
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch((v ?? '').trim())
                                ? 'Masukkan email yang valid.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          if (verify)
                            TextFormField(
                              controller: code,
                              decoration: const InputDecoration(
                                labelText: 'Kode verifikasi',
                                hintText: '6 digit',
                                prefixIcon: Icon(Icons.password_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: (v) => v?.length != 6
                                  ? 'Kode harus berisi 6 digit.'
                                  : null,
                              onFieldSubmitted: (_) => busy ? null : submit(),
                            ),
                          if (!verify)
                            TextFormField(
                              controller: password,
                              decoration: InputDecoration(
                                labelText: 'Kata sandi',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: hidden
                                      ? 'Tampilkan kata sandi'
                                      : 'Sembunyikan kata sandi',
                                  onPressed: () =>
                                      setState(() => hidden = !hidden),
                                  icon: Icon(
                                    hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              obscureText: hidden,
                              autofillHints: [
                                register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              enableSuggestions: false,
                              autocorrect: false,
                              maxLength: 128,
                              validator: (v) => (v ?? '').length < 8
                                  ? 'Kata sandi minimal 8 karakter.'
                                  : null,
                              onFieldSubmitted: (_) =>
                                  register || busy ? null : submit(),
                            ),
                          if (register) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: confirmation,
                              obscureText: hidden,
                              decoration: const InputDecoration(
                                labelText: 'Ulangi kata sandi',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) => v != password.text
                                  ? 'Kata sandi belum sama.'
                                  : null,
                              onFieldSubmitted: (_) => busy ? null : submit(),
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            Notice(error!, error: true),
                          ],
                          if (notice != null) ...[
                            const SizedBox(height: 16),
                            Notice(notice!),
                          ],
                          const SizedBox(height: 24),
                          BusyButton(
                            busy: busy,
                            onPressed: submit,
                            label: verify
                                ? 'Verifikasi email'
                                : register
                                ? 'Buat akun'
                                : 'Masuk',
                            icon: verify
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (verify)
                      Center(
                        child: TextButton(
                          onPressed: busy || cooldown > 0 ? null : resend,
                          child: Text(
                            cooldown > 0
                                ? 'Kirim ulang dalam ${cooldown}s'
                                : 'Kirim ulang kode',
                          ),
                        ),
                      ),
                    if (!verify)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            register
                                ? 'Sudah punya akun?'
                                : 'Belum punya akun?',
                            style: TextStyle(color: c.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => context.go(
                                    register ? '/login' : '/register',
                                  ),
                            child: Text(register ? 'Masuk' : 'Daftar'),
                          ),
                        ],
                      ),
                    if (!register && !verify)
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(
                            '/verify?email=${Uri.encodeComponent(email.text.trim())}',
                          ),
                          child: const Text('Verifikasi email saya'),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Foto. Tandai lokasi. Pantau penanganan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
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
    );
  }
}
