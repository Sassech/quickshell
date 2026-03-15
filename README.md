# System Tray Widget para Quickshell

Widget completo de bandeja del sistema con detección automática de apps SNI,
intercepción del cierre de ventanas y configuración por app.

## Estructura de archivos

```
SystemTray/
├── shell.qml               # Entry point de Quickshell
├── SystemTrayWidget.qml    # Widget principal (lógica, persistencia)
├── TrayIcon.qml            # Ícono individual por app
└── TrayConfigButton.qml    # Botón ⚙ + panel de configuración
```

## Requisitos

- **Quickshell** ≥ 0.1.0 con el módulo `Quickshell.Services.SystemTray`
- Compositor Wayland con soporte **StatusNotifierWatcher** (Hyprland, sway, KWin, etc.)
- Las apps deben implementar el protocolo **StatusNotifierItem** (SNI):
  - Discord ✓, Spotify ✓, Telegram ✓, Slack ✓, Element ✓, Nextcloud ✓, etc.

## Instalación

```bash
# Arch Linux
yay -S quickshell-git

# Copia los archivos a tu config
mkdir -p ~/.config/quickshell/tray
cp SystemTray/* ~/.config/quickshell/tray/

# Ejecutar
quickshell -p ~/.config/quickshell/tray/shell.qml
```

## Cómo funciona

### Detección automática

Quickshell se suscribe al bus D-Bus y escucha el protocolo **StatusNotifierItem**.
Cuando una app como Discord o Spotify se registra en el bus (lo hacen automáticamente
al iniciarse), `SystemTray.items` se actualiza y el `Repeater` agrega el ícono.

No necesitas configurar nada manualmente.

### Interceptar el cierre (minimize to tray)

En `TrayIcon.qml`, la conexión al objeto `trayItem.window`:

```qml
Connections {
    target: trayItem.window
    function onCloseRequested() {
        trayItem.window.visible = false  // ocultar en vez de cerrar
    }
}
```

Cuando el usuario pulsa la **X** de la ventana, el compositor emite `closeRequested`.
En lugar de destruir la ventana, la ocultamos. La app sigue corriendo en segundo plano.

### Panel de configuración (⚙)

El botón de engranaje abre un panel con todas las apps detectadas.
Cada app tiene un toggle ON/OFF.

**Modo blocklist (por defecto):** todas las apps aparecen, el usuario bloquea las que no quiere.

**Modo allowlist:** solo aparecen las apps marcadas explícitamente.

Las preferencias se guardan en:

```
~/.config/quickshell/SystemTray.conf
```

## Integración con una barra existente

Si ya tienes una barra en Quickshell, importa el widget directamente:

```qml
// En tu bar.qml
import "ruta/a/SystemTray"

PanelWindow {
    RowLayout {
        // ... otros widgets

        SystemTrayWidget {}
    }
}
```

O bien incluye solo la fila de íconos sin el `PanelWindow`:

```qml
// Dentro de tu layout de barra
Row {
    SystemTray { id: tray }

    Repeater {
        model: tray.items
        delegate: TrayIcon {
            required property var modelData
            trayItem: modelData
        }
    }
}
```

## Personalización visual

El tema usa colores de **Catppuccin Mocha** por defecto. Para cambiar:

| Variable     | Color actual | Descripción        |
| ------------ | ------------ | ------------------ |
| Fondo panel  | `#1e1e2e`    | Base de Catppuccin |
| Hover ítem   | `#313244`    | Surface0           |
| Texto activo | `#cdd6f4`    | Text               |
| Badge ON     | `#a6e3a1`    | Green              |
| Borde        | `#45475a`    | Surface1           |

## Notas

- Algunas apps como **Steam** no usan SNI estándar y pueden requerir
  `libappindicator` instalado.
- **Spotify** en Linux implementa SNI desde la versión 1.1.56+.
- Si una app no aparece, verifica que `StatusNotifierWatcher` esté activo:
  ```bash
  busctl --user | grep StatusNotifier
  ```
