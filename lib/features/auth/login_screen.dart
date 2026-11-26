import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../services/bungtemin_api.dart';
import 'otp_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onAuthenticated,
    this.reasonMessage,
    this.showBackButton = false,
    this.initialSsoEnabled,
  });

  final ValueChanged<UserSession> onAuthenticated;
  final String? reasonMessage;
  final bool showBackButton;
  final bool? initialSsoEnabled;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _noregCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _api = BungteminApi();
  bool _loading = false;
  bool _sendingOtp = false;
  bool _msWaiting = false;
  bool _msCancelled = false;
  bool _obscure = true;
  bool _ssoEnabled = false;
  String? _errorText;
  String? _infoText;

  @override
  void initState() {
    super.initState();
    _ssoEnabled = widget.initialSsoEnabled ?? false;
    if (widget.initialSsoEnabled == null) {
      _loadSsoConfig();
    }
    _checkWaOtpStatus();
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSsoEnabled != oldWidget.initialSsoEnabled &&
        widget.initialSsoEnabled != null) {
      _ssoEnabled = widget.initialSsoEnabled!;
    }
  }

  Future<void> _checkWaOtpStatus() async {
    final st = await _api.fetchWaOtpStatus();
    if (!mounted || st.waOnline) return;
    setState(() {
      _errorText = st.message.isNotEmpty
          ? st.message
          : 'Bot WhatsApp OTP sedang offline. OTP dialihkan ke Email (jika terdaftar) atau login pakai Kata Sandi / Microsoft SSO.';
    });
  }

  Future<void> _loadSsoConfig() async {
    final enabled = await _api.fetchSsoEnabled();
    if (!mounted) return;
    setState(() {
      _ssoEnabled = enabled;
    });
  }

  Future<void> _loginWithMicrosoft() async {
    if (!_ssoEnabled || _loading || _msWaiting) return;
    setState(() {
      _msWaiting = true;
      _msCancelled = false;
      _errorText = null;
      _infoText = 'Menunggu konfirmasi login Microsoft di browser...';
    });

    try {
      final appSession = _api.generateMsAppSession();
      final uid = await SessionStore().getOrCreateUidFallback();
      final uri = _api.buildMsLoginUri(appSession: appSession, uid: uid);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw BungteminApiException('Gagal membuka browser untuk login Microsoft.');
      }

      for (var i = 0; i < 90; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || _msCancelled) return;
        try {
          final session = await _api.checkMsAppLoginStatus(
            appSession: appSession,
            uid: uid,
          );
          if (session != null) {
            await SessionStore().save(session);
            if (!mounted) return;
            widget.onAuthenticated(session);
            return;
          }
        } on BungteminApiException {
          rethrow;
        } catch (_) {
          // Abaikan gangguan jaringan sesaat selama user masih di browser
        }
      }

      if (mounted && !_msCancelled) {
        setState(() {
          _errorText = 'Waktu tunggu login Microsoft habis. Silakan coba lagi.';
          _infoText = null;
        });
      }
    } catch (e) {
      if (mounted && !_msCancelled) {
        setState(() {
          _errorText = e.toString();
          _infoText = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _msWaiting = false);
      }
    }
  }

  @override
  void dispose() {
    _msCancelled = true;
    _noregCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final noreg = _noregCtrl.text.trim();
    final secret = _secretCtrl.text.trim();
    if (noreg.isEmpty || secret.isEmpty) {
      setState(() {
        _errorText = 'Noreg dan PIN / OTP wajib diisi.';
        _infoText = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      final session = await _api.login(noreg: noreg, secret: secret);
      await SessionStore().save(session);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestOtp() async {
    final raw = _noregCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _errorText = 'Isi Noreg terlebih dahulu.';
        _infoText = null;
      });
      return;
    }
    setState(() {
      _sendingOtp = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      final msg = await _api.requestOtpWa(noreg: raw);
      if (!mounted) return;
      final session = await Navigator.of(context).push<UserSession>(
        MaterialPageRoute<UserSession>(
          builder: (_) => OtpVerifyScreen(
            noreg: raw,
            initialInfo: msg,
          ),
        ),
      );
      if (session != null && mounted) {
        widget.onAuthenticated(session);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = widget.showBackButton || Navigator.of(context).canPop();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navy,
              AppColors.navyDeep,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (canGoBack)
                Positioned(
                  top: 8,
                  left: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Kembali',
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, canGoBack ? 52 : 28, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Image.asset(
                              'assets/img/appicon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.gold,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Bungtemin',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.reasonMessage != null &&
                            widget.reasonMessage!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.reasonMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFBAE6FD),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _noregCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Noreg',
                                    hintText: 'Contoh: 00123456',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _secretCtrl,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submitLogin(),
                                  decoration: InputDecoration(
                                    labelText: 'PIN / OTP / Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_errorText != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorText!,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (_infoText != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _infoText!,
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: _loading ? null : _submitLogin,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Masuk',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                                if (_ssoEnabled) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : (_msWaiting
                                            ? () {
                                                setState(() {
                                                  _msCancelled = true;
                                                  _msWaiting = false;
                                                  _infoText = null;
                                                });
                                              }
                                            : _loginWithMicrosoft),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: _msWaiting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.window_rounded,
                                            size: 18,
                                            color: Color(0xFF0284C7),
                                          ),
                                    label: Text(
                                      _msWaiting
                                          ? 'Batalkan Login Microsoft'
                                          : 'Login Microsoft',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: (_loading || _sendingOtp)
                                        ? null
                                        : _requestOtp,
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: AppColors.emerald,
                                    ),
                                    label: Text(
                                      _sendingOtp
                                          ? 'Mengirim...'
                                          : 'Kirim OTP WA',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
