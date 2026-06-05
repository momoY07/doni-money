import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/i18n.dart';

class PasscodeSetupSheet extends StatefulWidget {
  final String language;

  const PasscodeSetupSheet({super.key, required this.language});

  @override
  State<PasscodeSetupSheet> createState() => _PasscodeSetupSheetState();
}

class _PasscodeSetupSheetState extends State<PasscodeSetupSheet> {
  late final TextEditingController _passcodeCtrl;
  late final TextEditingController _confirmCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passcodeCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _passcodeCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final first = _passcodeCtrl.text.trim();
    final second = _confirmCtrl.text.trim();
    final reg = RegExp(r'^\d{4}$');

    if (!reg.hasMatch(first) || !reg.hasMatch(second)) {
      setState(() {
        _errorText = t('passcode_invalid', widget.language);
      });
      return;
    }

    if (first != second) {
      setState(() {
        _errorText = t('passcode_mismatch', widget.language);
      });
      return;
    }

    Navigator.pop(context, first);
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
              t('create_passcode', widget.language),
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
                labelText: t('enter_passcode', widget.language),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: t('confirm_passcode', widget.language),
                errorText: _errorText,
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(t('save', widget.language)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
