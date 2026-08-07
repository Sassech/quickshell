pragma Singleton
import QtQuick

// ── IconHelpers — singleton con funciones de ícono por umbrales ───────────────
// Centraliza los ternarios de umbrales duplicados entre CcSliders, VolumeOsd y
// BrightnessOsd. Recibe la magnitud en la misma unidad que cada fuente emite
// (volumen en fracción 0..1, brillo en pct 0..100) y devuelve el glyph.
QtObject {
    // ── Ícono por umbrales (volumen en fracción 0..1) ─────────────────────
    function volIcon(vol, muted) {
        if (muted || vol === 0) return "󰝟"
        if (vol < 0.33) return "󰕿"
        if (vol < 0.67) return "󰖀"
        return "󰕾"
    }

    // ── Ícono por umbrales (brillo en pct 0..100) ─────────────────────────
    function brightIcon(pct) {
        if (pct < 15) return "󰃞"
        if (pct < 50) return "󰃝"
        if (pct < 85) return "󰃟"
        return "󰃠"
    }
}
