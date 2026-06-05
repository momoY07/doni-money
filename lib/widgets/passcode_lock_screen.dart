import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/i18n.dart';
import '../storage.dart';

class PasscodeLockScreen extends StatefulWidget {
  final String language;
  final VoidCallback onUnlocked;

  const PasscodeLockScreen({
    super.key,
    required this.language,
    required this.onUnlocked,
  });

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  late final TextEditingController _passcodeCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passcodeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _passcodeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _passcodeCtrl.text.trim();
    final saved = Storage.txBox.get('lockPasscode', defaultValue: '') as String;

    if (input == saved && saved.isNotEmpty) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _errorText = t('wrong_passcode', widget.language);
      _passcodeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 56,
                        color: Color(0xFF9C7A22),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('app_locked', widget.language),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('app_unlock_message', widget.language),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8A7440),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _passcodeCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        obscureText: true,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: t('enter_passcode', widget.language),
                          errorText: _errorText,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: Text(t('unlock', widget.language)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
