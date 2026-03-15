# Verificación del System Tray Widget

## 1. Verificar requisitos

### Quickshell versión

```bash
quickshell --version
# Debe ser ≥ 0.1.0
```

### StatusNotifierWatcher activo

```bash
busctl --user | grep StatusNotifier
# Debe aparecer: org.kde.StatusNotifierWatcher o similar
```

### Apps con soporte SNI disponibles

```bash
# Verifica si tienes algunas de estas apps instaladas:
which discord spotify telegram-desktop slack element-desktop
```

## 2. Recargar Quickshell

```bash
# Opción 1: Reiniciar con replace (recomendado)
quickshell --replace

# Opción 2: Matar proceso y reiniciar
pkill quickshell && quickshell &

# Opción 3: Desde Hyprland
hyprctl dispatch exec "quickshell --replace"
```

## 3. Verificar que el widget funciona

### Paso 1: Lanzar una app SNI

```bash
# Ejemplo con Discord (si está instalado)
discord &

# O Spotify
spotify &

# O cualquier app que soporte StatusNotifierItem
```

### Paso 2: Observar la barra superior

- Los íconos deben aparecer automáticamente en la barra superior
- Ubicación: sección derecha, entre DiskWidget y Battery
- Los íconos deben ser visibles y tener el tamaño correcto

### Paso 3: Probar interactividad

- **Hover**: debe mostrar tooltip con nombre de la app
- **Click izquierdo**: debe activar/enfocar la ventana de la app
- **Click derecho**: debe abrir menú contextual (si la app lo implementa)

## 4. Debugging

### Si no aparecen íconos

1. **Verificar logs de Quickshell**:

```bash
quickshell 2>&1 | grep -i "systemtray\|statusnotifier"
```

2. **Verificar que SystemTray está disponible**:
   Crear archivo temporal `/tmp/test-systray.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

ShellRoot {
    Component.onCompleted: {
        console.log("SystemTray items:", SystemTray.items.length)
        for (var i = 0; i < SystemTray.items.length; i++) {
            console.log("- Item:", SystemTray.items[i].id || SystemTray.items[i].title)
        }
    }
}
```

Ejecutar:

```bash
quickshell -p /tmp/test-systray.qml
```

3. **Verificar D-Bus**:

```bash
# Listar servicios SNI activos
busctl --user tree org.kde.StatusNotifierWatcher 2>/dev/null

# Monitor eventos SNI en tiempo real
dbus-monitor --session "interface='org.kde.StatusNotifierItem'" &
# Luego lanzar Discord u otra app y ver si aparecen eventos
```

### Si hay errores de QML

```bash
# Ver errores en tiempo real
journalctl --user -f | grep quickshell
```

### Si los íconos no se muestran correctamente

- Verificar que Theme.qml tenga los colores definidos
- Probar con `iconSize` mayor (ej: 24) en TopBar.qml
- Verificar permisos de lectura en las rutas de íconos del sistema

## 5. Apps recomendadas para probar

| App      | Paquete Arch       | Soporte SNI                   |
| -------- | ------------------ | ----------------------------- |
| Discord  | `discord`          | ✅ Nativo                     |
| Spotify  | `spotify`          | ✅ Nativo (≥ 1.1.56)          |
| Telegram | `telegram-desktop` | ✅ Nativo                     |
| Slack    | `slack-desktop`    | ✅ Nativo                     |
| Steam    | `steam`            | ⚠️ Requiere `libappindicator` |
| Element  | `element-desktop`  | ✅ Nativo                     |

## 6. Troubleshooting común

### "Module Quickshell.Services.SystemTray not found"

➜ Tu versión de Quickshell no incluye el módulo. Actualiza a ≥ 0.1.0:

```bash
yay -S quickshell-git
```

### "SystemTray.items is undefined"

➜ StatusNotifierWatcher no está corriendo. Verifica que tu compositor lo soporte:

```bash
# Para Hyprland, asegúrate que esté en el PATH
which hyprland-statusnotifier || echo "No encontrado"
```

### Los íconos aparecen pero están en blanco

➜ Problema con rutas de íconos. Editar TrayIcon.qml para depurar:

```qml
Component.onCompleted: {
    console.log("Tray item:", trayItem.id, "icon:", trayItem.icon)
}
```

## 7. Personalización

### Cambiar tamaño de íconos

Editar [Components/TopBar.qml](Components/TopBar.qml):

```qml
SystemTrayWidget {
    iconSize: 20  // Cambiar este valor (default: 18)
    spacing: 6    // Espaciado entre íconos (default: 4)
}
```

### Cambiar posición en la barra

Mover el bloque `SystemTrayWidget {}` en TopBar.qml a otra ubicación en `rightSection`, `leftSection` o `centerSection`.

### Cambiar colores

Los colores se heredan de [Components/Theme.qml](Components/Theme.qml):

- `Theme.surface3` - fondo hover
- `Theme.muted1` - texto fallback
- `Theme.text` - tooltip

## Resultado esperado

Si todo funciona correctamente, deberías ver:

- ✅ Íconos de apps SNI apareciendo automáticamente en la barra
- ✅ Tooltips al pasar el mouse
- ✅ Ventanas activándose al hacer click
- ✅ Widget invisible cuando no hay apps en el tray
- ✅ Actualización automática cuando apps entran/salen del tray
