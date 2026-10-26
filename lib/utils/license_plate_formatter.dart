import 'package:flutter/services.dart';

String normalizeLicensePlate(String value) {
  final compact = value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]+'), '');

  if (compact.isEmpty) {
    return '';
  }

  final match = RegExp(r'^(.+?)(\d{1,4})$').firstMatch(compact);

  if (match == null) {
    return compact;
  }

  return '${match.group(1)}-${match.group(2)}';
}

bool isValidLicensePlate(String value) {
  final normalized = normalizeLicensePlate(value);

  return RegExp(
    r'^[0-9A-Z\u0E01-\u0E5B]+-\d{1,4}$',
  ).hasMatch(normalized);
}

class LicensePlateFormatter extends TextInputFormatter {
  const LicensePlateFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeLicensePlate(newValue.text);

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(
        offset: normalized.length,
      ),
    );
  }
}