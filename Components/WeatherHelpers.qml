import QtQuick 2.15

QtObject {
    function wmoIcon(code, day) {
        if (code === 0)          return day ? "☀" : "🌙"
        if (code <= 2)           return day ? "🌤" : "☁"
        if (code === 3)          return "☁"
        if (code <= 49)          return "🌫"
        if (code <= 57)          return "🌦"
        if (code <= 67)          return "🌧"
        if (code <= 77)          return "❄"
        if (code <= 82)          return "🌦"
        if (code <= 86)          return "🌨"
        if (code <= 99)          return "⛈"
        return "🌡"
    }
    
    function wmoDescription(code) {
        if (code === 0)          return "Despejado"
        if (code === 1)          return "Principalmente despejado"
        if (code === 2)          return "Parcialmente nublado"
        if (code === 3)          return "Nublado"
        if (code <= 49)          return "Niebla"
        if (code <= 55)          return "Llovizna"
        if (code <= 57)          return "Llovizna helada"
        if (code <= 65)          return "Lluvia"
        if (code <= 67)          return "Lluvia helada"
        if (code <= 73)          return "Nieve ligera"
        if (code <= 75)          return "Nieve intensa"
        if (code === 77)         return "Granizo"
        if (code <= 82)          return "Chubascos"
        if (code <= 86)          return "Nieve con lluvia"
        if (code <= 99)          return "Tormenta"
        return "Desconocido"
    }
}
