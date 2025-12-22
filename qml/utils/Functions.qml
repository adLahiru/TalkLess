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
}
