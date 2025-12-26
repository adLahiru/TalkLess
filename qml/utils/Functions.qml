pragma Singleton
import QtQuick

QtObject {
    function formatDate(date) {
        return Qt.formatDate(date, "dd MMM yyyy")
    }
    
    function formatTime(date) {
        return Qt.formatTime(date, "hh:mm AP")
    }
    
    function formatDateTime(date) {
        return Qt.formatDateTime(date, "dd MMM yyyy hh:mm AP")
    }
    
    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value))
    }
    
    function lerp(start, end, t) {
        return start + (end - start) * t
    }
    
    // dB conversion functions
    function linearToDb(linear) {
        if (linear <= 0) return -60
        return 20 * Math.log10(linear)
    }
    
    function dbToLinear(db) {
        if (db <= -60) return 0
        return Math.pow(10, db / 20)
    }
    
    function formatDb(db) {
        if (db <= -60) return "-∞ dB"
        return db.toFixed(1) + " dB"
    }
}
