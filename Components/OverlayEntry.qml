// qmllint disable uncreatable-type
import QtQuick
import QtQml

// OverlayEntry — un registro de overlay dentro de OverlaysManager.overlays. Data-driven: todo lo que el modal y el shell necesitan sobre un overlay vive aquí (metadatos + estado), además
// de la fuente del componente que lo instancia. Agregar un overlay nuevo = crear su .qml + una entrada OverlayEntry aquí; no se toca ni OverlaysControl ni shell.qml.
QtObject {
    id: root

    // Registro (id único para persistencia y lookup)
    property string entryId: "overlay"
    property string name: ""
    property string description: ""
    property string icon: ""
    property string source: ""          // ruta al .qml que instancia este overlay

    // Estado (persistido)
    property bool enabled: true
    property bool onTop:   true

    // Posición (px relativos a la esquina anclada)
    property int topOffset:    0
    property int bottomOffset: 0
    property int leftOffset:   0
    property int rightOffset:  0
}