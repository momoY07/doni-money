import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/i18n.dart';
import '../storage.dart';

class PasscodeVerifySheet extends StatefulWidget {
  final String language;

  const PasscodeVerifySheet({super.key, required this.language});

  @override
  State<PasscodeVerifySheet> createState() => _PasscodeVerifySheetState();
}

class _PasscodeVerifySheetState extends State<PasscodeVerifySheet> {
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

  void _verify() {
    final input = _passcodeCtrl.text.trim();
    final saved = Storage.txBox.get('lockPasscode', defaultValue: '') as String;

    if (input == saved && saved.isNotEmpty) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _errorText = t('wrong_passcode', widget.language);
      _passcodeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('passcode_lock', widget.language),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passcodeCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: t('current_passcode', widget.language),
                errorText: _errorText,
                counterText: '',
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _verify,
                child: Text(t('unlock', widget.language)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
