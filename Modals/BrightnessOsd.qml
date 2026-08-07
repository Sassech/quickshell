// qmllint disable uncreatable-type
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
// BrightnessOsd — OSD de brillo. Hereda OsdBase (ciclo de vida + layout) y
// bindea su contenido: icono por umbrales, label con %, barra sobre 100.
// La fifo (qs-brightness-fifo.sh) entrega el pct; show(pct) lo recibe y llama
// showCard() de la base.
// ─────────────────────────────────────────────────────────────────────────────
OsdBase {
    id: root

    cardWidth: 272

    // ── Contenido parametrizado ───────────────────────────────────────────
    value: _pct
    icon:  _pct < 15 ? "󰃞"
         : _pct < 50 ? "󰃝"
         : _pct < 85 ? "󰃟"
         : "󰃠"
    label: _pct + "%"

    property int _pct: 0   // 0–100

    function show(pct) {
        root._pct = Math.max(0, Math.min(100, pct))
        root.showCard()
    }
}
