import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../services/bungtemin_api.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.noreg,
    this.initialInfo,
  });

  final String noreg;
  final String? initialInfo;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _api = BungteminApi();

  bool _verifying = false;
  bool _resending = false;
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  String? _errorText;
  String? _infoText;

  @override
  void initState() {
    super.initState();
    _infoText = widget.initialInfo;
    _otpFocus.addListener(_onFocusChange);
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocus.requestFocus();
      }
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpFocus.removeListener(_onFocusChange);
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _verifyOtp([String? forcedCode]) async {
    if (_verifying) return;
    final code = (forcedCode ?? _otpCtrl.text).trim();
    if (code.length != 6) {
      setState(() {
        _errorText = 'Masukkan 6 digit kode OTP.';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final session = await _api.login(noreg: widget.noreg, secret: code);
      await SessionStore().save(session);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resending || _verifying || _cooldownSeconds > 0) return;
    setState(() {
      _resending = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      final msg = await _api.requestOtpWa(noreg: widget.noreg);
      if (!mounted) return;
      _otpCtrl.clear();
      setState(() => _infoText = msg);
      _startCooldown();
      _otpFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  void _onOtpChanged(String value) {
    setState(() {
      if (_errorText != null) _errorText = null;
    });
    if (value.length == 6) {
      _verifyOtp(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _otpCtrl.text;
    final formattedNoreg = SessionStore.formatNoreg8(widget.noreg);

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
              Positioned(
                top: 8,
                left: 12,
                child: IconButton(
                  onPressed:
                      _verifying ? null : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Kembali',
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.mark_chat_read_rounded,
                              color: AppColors.emerald,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Verifikasi OTP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Noreg: $formattedNoreg',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                                Text(
                                  _infoText ??
                                      'Masukkan 6 digit kode OTP yang dikirim ke WhatsApp / Email terdaftar.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: () => _otpFocus.requestFocus(),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Hidden TextField so Android soft-keyboard, backspace, paste & autofill work natively
                                      SizedBox(
                                        height: 54,
                                        child: Opacity(
                                          opacity: 0.01,
                                          child: TextField(
                                            controller: _otpCtrl,
                                            focusNode: _otpFocus,
                                            enabled: !_verifying,
                                            keyboardType: TextInputType.number,
                                            textInputAction: TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode,
                                            ],
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                6,
                                              ),
                                            ],
                                            onChanged: _onOtpChanged,
                                            onSubmitted: (_) => _verifyOtp(),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              counterText: '',
                                            ),
                                          ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(6, (index) {
                                            final hasDigit =
                                                index < code.length;
                                            final isActive =
                                                _otpFocus.hasFocus &&
                                                    (index == code.length ||
                                                        (code.length == 6 &&
                                                            index == 5));
                                            final char =
                                                hasDigit ? code[index] : '';
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 140,
                                              ),
                                              width: 44,
                                              height: 54,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: hasDigit
                                                    ? const Color(0xFFEFF6FF)
                                                    : const Color(0xFFF8FAFC),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _errorText != null
                                                      ? const Color(0xFFEF4444)
                                                      : isActive
                                                          ? AppColors.primaryBlue
                                                          : hasDigit
                                                              ? AppColors.sky
                                                              : const Color(
                                                                  0xFFCBD5E1,
                                                                ),
                                                  width: isActive ? 2 : 1.4,
                                                ),
                                              ),
                                              child: Text(
                                                char,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.navy,
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_errorText != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    _errorText!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: (_verifying || code.length != 6)
                                      ? null
                                      : () => _verifyOtp(),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _verifying
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Verifikasi & Masuk',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: (_resending ||
                                            _verifying ||
                                            _cooldownSeconds > 0)
                                        ? null
                                        : _resendOtp,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _resending
                                          ? 'Mengirim ulang...'
                                          : _cooldownSeconds > 0
                                              ? 'Kirim ulang OTP ($_cooldownSeconds dtk)'
                                              : 'Kirim Ulang OTP',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
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
