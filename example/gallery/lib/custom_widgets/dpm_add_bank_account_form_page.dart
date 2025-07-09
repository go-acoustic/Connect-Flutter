import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import your custom widget
import 'eg_text_input_tealeaf_widget.dart';

class DPMAddBankAccountFormPage extends StatefulWidget {
  const DPMAddBankAccountFormPage({super.key});

  @override
  State<DPMAddBankAccountFormPage> createState() =>
      _DPMAddBankAccountFormPageState();
}

class _DPMAddBankAccountFormPageState extends State<DPMAddBankAccountFormPage> {
  // Mock state management
  bool _isValidateInputIban = false;
  bool _ibanEdited = false;
  final bool _showError = false;
  final bool _canShowBic = true;
  bool _aliasEdited = false;
  final bool _isButtonEnabled = true;
  String _ibanValue = '';
  String _bicValue = '';
  String _aliasValue = '';

  @override
  void initState() {
    super.initState();
  }

  void _onIbanChanged(String value) {
    setState(() {
      _ibanValue = value;
      _ibanEdited = true;
    });
  }

  void _onBicChanged(String value) {
    setState(() {
      _bicValue = value;
    });
  }

  void _onAliasChanged(String value) {
    setState(() {
      _aliasValue = value;
      _aliasEdited = true;
    });
  }

  void _onValidateInputIban(bool hasFocus) {
    setState(() {
      _isValidateInputIban = hasFocus;
    });
  }

  String? _validateIban(String? value) {
    if (!_ibanEdited) return null;
    if (_ibanValue.isEmpty) return 'Cannot be empty';
    if (_ibanValue.length > 24) return 'Invalid IBAN';
    return null;
  }

  String? _validateBic(String? value) {
    if (_bicValue.isEmpty) return 'Cannot be empty';
    return null;
  }

  String? _validateAlias(String? value) {
    if (!_aliasEdited) return null;
    if (_aliasValue.isEmpty) return 'Cannot be empty';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bank Account'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              'Add Bank Account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 24),
          Focus(
            onFocusChange: _onValidateInputIban,
            child: Semantics(
              label: 'Shrine - Tealeaf masking label',
              hint: 'Shrine - Tealeaf test hint',
              excludeSemantics: true,
              child: EGTextInputTealeafWidget(
                label: 'IBAN',
                hintText: 'Enter IBAN',
                inputType: TextInputType.text,
                labelAccessibilityLabel: 'Account number label',
                textFieldAccessibilityLabel: 'Account number input field',
                inputFormatters: [UpperCaseInputFormatter()],
                onChanged: _onIbanChanged,
                autovalidate: _isValidateInputIban,
                validator: _validateIban,
              ),
            ),
          ),
          const SizedBox(height: 24),
          EGTextInputTealeafWidget(
            label: 'BIC',
            hintText: 'Enter BIC',
            bottomLabel: 'Only inter-account',
            inputType: TextInputType.text,
            inputFormatters: [UpperCaseInputFormatter()],
            onChanged: _onBicChanged,
            autovalidate: _showError,
            enabled: _canShowBic,
            validator: _validateBic,
          ),
          const SizedBox(height: 24),
          EGTextInputTealeafWidget(
            label: 'Alias Account',
            hintText: 'Enter alias account',
            inputType: TextInputType.text,
            onChanged: _onAliasChanged,
            autovalidate: _showError,
            validator: _validateAlias,
          ),
          const SizedBox(height: 48),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _isButtonEnabled
                  ? () {
                      // Handle save action
                      debugPrint('Saving bank account...');
                    }
                  : null,
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Custom input formatter for uppercase
class UpperCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
