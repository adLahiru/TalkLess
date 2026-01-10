#pragma once
#include <QString>
#include <QKeySequence>
#include <QSet>

/**
 * Validates hotkey combinations for cross-platform reliability.
 * Blocks combinations that are problematic on certain keyboard layouts or systems.
 */
class HotkeyValidator
{
public:
    enum class ValidationResult {
        Valid,
        InvalidEmpty,
        InvalidSingleKey,
        InvalidDeadKey,
        InvalidShiftedNumber,
        InvalidSystemReserved,
        InvalidShiftedSymbol
    };

    struct ValidationInfo {
        ValidationResult result;
        QString message;
        bool isValid() const { return result == ValidationResult::Valid; }
    };

    /**
     * Validates a hotkey sequence string.
     * @param hotkeyText The hotkey string (e.g., "Ctrl+Shift+A")
     * @return ValidationInfo with result and user-friendly message
     */
    static ValidationInfo validate(const QString& hotkeyText);

    /**
     * Gets a user-friendly error message for a validation result.
     */
    static QString getValidationMessage(ValidationResult result, const QString& hotkeyText);

    /**
     * Checks if a key sequence contains problematic dead keys or shifted symbols.
     */
    static bool containsDeadKey(const QKeySequence& sequence);

    /**
     * Checks if a key sequence contains shifted number keys (like Ctrl+Shift+6).
     * These are problematic because Shift+Number produces different symbols per layout.
     */
    static bool containsShiftedNumber(const QKeySequence& sequence);

    /**
     * Checks if the hotkey is a Windows system reserved combination.
     */
    static bool isSystemReserved(const QKeySequence& sequence);

private:
    // Common dead keys that cause issues
    static const QSet<Qt::Key> s_deadKeys;
    
    // Problematic symbols produced by Shift+Number on various layouts
    static const QSet<Qt::Key> s_shiftedNumberSymbols;
};
