import 'package:flutter/services.dart';

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Get the new text and remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    StringBuffer newTextBuffer = StringBuffer();

    // Limit to 8 digits (DDMMYYYY)
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }

    for (int i = 0; i < digitsOnly.length; i++) {
      newTextBuffer.write(digitsOnly[i]);
      if (i == 1 && digitsOnly.length >= 2) { // After the 2nd digit (DD)
        newTextBuffer.write('/');
      } else if (i == 3 && digitsOnly.length >= 4) { // After the 4th digit (MM)
        newTextBuffer.write('/');
      }
    }

    // Calculate the new cursor position
    int selectionIndex = newTextBuffer.length;

    // If a '/' was just added, and the original cursor was before it,
    // try to keep the cursor in a sensible place.
    // This part can be tricky and might need refinement based on desired UX.
    if (newValue.selection.end == oldValue.selection.end + 1 &&
        (newTextBuffer.length == 3 || newTextBuffer.length == 6) &&
        newTextBuffer.toString().endsWith('/')) {
      // Heuristic: if a slash was added, keep cursor after it
      // This might not be perfect for all edge cases of deletion/insertion around slashes.
    }

    return TextEditingValue(
      text: newTextBuffer.toString(),
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}