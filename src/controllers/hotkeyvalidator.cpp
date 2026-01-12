#include "hotkeyvalidator.h"
#include <QKeySequence>
#include <QDebug>

// Dead keys that are commonly used for accents and cause issues
const QSet<Qt::Key> HotkeyValidator::s_deadKeys = {
    Qt::Key_AsciiCircum,    // ^ (Shift+6 on US layout)
    Qt::Key_Dead_Grave,     // `
    Qt::Key_Dead_Acute,     // ´
    Qt::Key_Dead_Circumflex,// ^
    Qt::Key_Dead_Tilde,     // ~
    Qt::Key_Dead_Diaeresis  // ¨
};

// Symbols produced by Shift+Number that vary by keyboard layout
const QSet<Qt::Key> HotkeyValidator::s_shiftedNumberSymbols = {
    Qt::Key_Exclam,         // ! (Shift+1)
    Qt::Key_At,             // @ (Shift+2)
    Qt::Key_NumberSign,     // # (Shift+3)
    Qt::Key_Dollar,         // $ (Shift+4)
    Qt::Key_Percent,        // % (Shift+5)
    Qt::Key_AsciiCircum,    // ^ (Shift+6)
    Qt::Key_Ampersand,      // & (Shift+7)
    Qt::Key_Asterisk,       // * (Shift+8)
    Qt::Key_ParenLeft,      // ( (Shift+9)
    Qt::Key_ParenRight      // ) (Shift+0)
};

HotkeyValidator::ValidationInfo HotkeyValidator::validate(const QString& hotkeyText)
{
    ValidationInfo info;
    
    // Check if empty
    if (hotkeyText.trimmed().isEmpty()) {
        info.result = ValidationResult::InvalidEmpty;
        info.message = "Hotkey cannot be empty.";
        return info;
    }

    // Parse the key sequence
    QKeySequence sequence(hotkeyText, QKeySequence::PortableText);
    
    // Check if valid sequence
    if (sequence.isEmpty()) {
        info.result = ValidationResult::InvalidEmpty;
        info.message = "Invalid hotkey format.";
        return info;
    }

    // Get key and modifiers from the sequence
    QKeyCombination keyComb = sequence[0];
    Qt::KeyboardModifiers modifiers = keyComb.keyboardModifiers();
    Qt::Key key = keyComb.key();

    // Check if it's just a modifier key alone (no actual key)
    if (key == Qt::Key_Control || key == Qt::Key_Shift || 
        key == Qt::Key_Alt || key == Qt::Key_Meta) {
        info.result = ValidationResult::InvalidSingleKey;
        info.message = "Hotkey must include a non-modifier key (like a letter or F-key).";
        return info;
    }

    // Require at least one modifier (Ctrl, Alt, or Shift)
    // Exception: Function keys (F1-F24) can be used alone
    bool isFunctionKey = (key >= Qt::Key_F1 && key <= Qt::Key_F24);
    if (modifiers == Qt::NoModifier && !isFunctionKey) {
        info.result = ValidationResult::InvalidSingleKey;
        info.message = "Hotkey must include at least one modifier (Ctrl, Alt, or Shift), or use an F-key.";
        return info;
    }

    // Check for dead keys
    if (containsDeadKey(sequence)) {
        info.result = ValidationResult::InvalidDeadKey;
        info.message = QString("Hotkey '%1' contains a dead key (^, `, ~) which may not work reliably.\n"
                              "Try using:\n"
                              "• F1-F12 keys (e.g., Ctrl+F6, Ctrl+F7)\n"
                              "• Letter keys (e.g., Ctrl+Shift+Q, Ctrl+Shift+W)\n"
                              "• Numpad keys")
                              .arg(hotkeyText);
        return info;
    }

    // NOTE: We no longer block Ctrl+Shift+Number combinations because
    // the HotkeyCapturePopup now normalizes them properly.
    // For example, when you press Ctrl+Shift+6, it receives Qt::Key_AsciiCircum (^)
    // but we normalize it back to "6", so the hotkey becomes "Ctrl+Shift+6"
    // instead of "Ctrl+Shift+^", which works correctly.
    
    // Check for shifted numbers (Ctrl+Shift+6, etc.) - DISABLED, now normalized in capture
    // if (containsShiftedNumber(sequence)) {
    //     info.result = ValidationResult::InvalidShiftedNumber;
    //     info.message = QString("Hotkey '%1' uses Shift + Number, which produces different symbols (^, &, etc.) "
    //                           "on different keyboard layouts and may not work reliably.\n\n"
    //                           "Try using instead:\n"
    //                           "• F-keys: Ctrl+F6, Ctrl+F7, Ctrl+Shift+F6\n"
    //                           "• Letters: Ctrl+Shift+Q, Ctrl+Shift+W\n"
    //                           "• Numpad: Ctrl+Num6, Ctrl+Num7")
    //                           .arg(hotkeyText);
    //     return info;
    // }

    // Check for system reserved hotkeys
    if (isSystemReserved(sequence)) {
        info.result = ValidationResult::InvalidSystemReserved;
        info.message = QString("Hotkey '%1' is reserved by Windows and cannot be registered.")
                              .arg(hotkeyText);
        return info;
    }

    // All checks passed
    info.result = ValidationResult::Valid;
    info.message = "Valid hotkey";
    return info;
}

bool HotkeyValidator::containsDeadKey(const QKeySequence& sequence)
{
    if (sequence.isEmpty()) return false;
    
    QKeyCombination keyComb = sequence[0];
    Qt::Key key = keyComb.key();
    
    return s_deadKeys.contains(key);
}

bool HotkeyValidator::containsShiftedNumber(const QKeySequence& sequence)
{
    if (sequence.isEmpty()) return false;
    
    QKeyCombination keyComb = sequence[0];
    Qt::KeyboardModifiers modifiers = keyComb.keyboardModifiers();
    Qt::Key key = keyComb.key();
    
    // Check if Shift modifier is present
    if (!(modifiers & Qt::ShiftModifier)) {
        return false;
    }
    
    // Check if the key is a number (0-9)
    if (key >= Qt::Key_0 && key <= Qt::Key_9) {
        return true;
    }
    
    // Also check for the symbols that result from Shift+Number
    if (s_shiftedNumberSymbols.contains(key)) {
        return true;
    }
    
    return false;
}

bool HotkeyValidator::isSystemReserved(const QKeySequence& sequence)
{
    if (sequence.isEmpty()) return false;
    
    QKeyCombination keyComb = sequence[0];
    Qt::KeyboardModifiers modifiers = keyComb.keyboardModifiers();
    Qt::Key key = keyComb.key();
    
    // Windows reserved combinations
    // Alt+Tab, Alt+Esc, Ctrl+Alt+Del, Win+L, etc.
    
    if ((modifiers == Qt::AltModifier) && (key == Qt::Key_Tab || key == Qt::Key_Escape)) {
        return true;
    }
    
    if ((modifiers == (Qt::ControlModifier | Qt::AltModifier)) && key == Qt::Key_Delete) {
        return true;
    }
    
    if (modifiers & Qt::MetaModifier) {
        // Most Win+ combinations are reserved
        // Allow very few combinations that might be safe
        if (key >= Qt::Key_0 && key <= Qt::Key_9) return true;
        if (key == Qt::Key_L || key == Qt::Key_D || key == Qt::Key_E || 
            key == Qt::Key_R || key == Qt::Key_X || key == Qt::Key_M) {
            return true;
        }
    }
    
    return false;
}

QString HotkeyValidator::getValidationMessage(ValidationResult result, const QString& hotkeyText)
{
    ValidationInfo info;
    info.result = result;
    
    switch (result) {
        case ValidationResult::Valid:
            return "Valid hotkey";
            
        case ValidationResult::InvalidEmpty:
            return "Hotkey cannot be empty.";
            
        case ValidationResult::InvalidSingleKey:
            return "Hotkey must include at least one modifier (Ctrl, Alt, or Shift).";
            
        case ValidationResult::InvalidDeadKey:
            return QString("Hotkey '%1' contains a dead key which may not work reliably. "
                          "Try using F-keys, letter keys, or numpad keys instead.")
                          .arg(hotkeyText);
            
        case ValidationResult::InvalidShiftedNumber:
            return QString("Hotkey '%1' uses Shift + Number which may not work reliably. "
                          "Try using F-keys (Ctrl+F6), letters (Ctrl+Shift+Q), or numpad keys instead.")
                          .arg(hotkeyText);
            
        case ValidationResult::InvalidSystemReserved:
            return QString("Hotkey '%1' is reserved by the system and cannot be used.")
                          .arg(hotkeyText);
            
        case ValidationResult::InvalidShiftedSymbol:
            return QString("Hotkey '%1' contains shifted symbols that may vary by keyboard layout.")
                          .arg(hotkeyText);
            
        default:
            return "Unknown validation error.";
    }
}
