pragma Singleton
import QtQuick

QtObject {
    id: root

    // Formatea segundos como "Xh Ym" o "Ym". Retorna "" si seconds <= 0.
    function fmtTime(seconds) {
        if (!seconds || seconds <= 0) return ""
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }
}
