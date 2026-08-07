# Quickshell Desktop Shell

Shell para compositor Wayland Quickshell con entorno de escritorio estilo Hyprland.

## Capturas de Interfaz

### Barra Superior (Top Bar)

![Top Bar](assets/topBar.png)

**Componentes:**

- [Barra Izquierda](assets/topBarLeft.png) - Widget de estado (CPU, RAM, Disco, Red, Bluetooth)
- [Centro](assets/topBarCenter.png) - Reloj, fecha y música
- [Derecha](assets/topBarRight.png) - Notificaciones y controles rápidos

### Modales del Sistema

![CPU](assets/cpuModal.png)
![RAM](assets/ramModal.png)
![Disco](assets/diskModal.png)
![GPU](assets/gpuModal.png)
![Ventilador](assets/fanModal.png)
![Batería](assets/batteryModal.png)

### Widgets de Estado

![Audio](assets/audio.png)
![Bluetooth](assets/bluethoot.png)
![WiFi](assets/wifiModal.png)
![Clima](assets/clima.png)
![Calendario](assets/calendar.png)
![Portapapeles](assets/clipBoard.png)
![Idioma](assets/languaje.png)

![Notificación de Música](assets/musicNotification.png)

## Características Principales

- **Widgets de estado en tiempo real**: CPU, RAM, Disco, GPU, Red, Bluetooth, Audio
- **Modales informativos**: Detalles del sistema, monitorización en vivo
- **Notificaciones**: Música, WiFi, sistema, clima
- **Portapapeles**: Historial con cliphist
- **Clima**: Integración con Open-Meteo API
- **Calendario**: Vista de fecha
- **Interfaz en español**: Todo el sistema comentado en español
- **Diseño Material You**: Tema Catppuccin Mocha

## Estructura de Proyecto

```
quickshell/
├── shell.qml           # Punto de entrada principal
├── Components/         # Elementos UI reutilizables (Theme.qml, TopBar.qml, SysData.qml, OverlaysManager.qml)
├── Widgets/            # Componentes de la barra de estado
├── Modals/             # Ventanas superpuestas (WeatherModal.qml, ControlCenter.qml)
│   ├── cc/             # Controladores y paneles del Centro de Control
│   └── overlays/       # OverlayWindow y overlays del sistema
├── scripts/            # Scripts backend (Bash/Python)
├── config/             # Archivos de configuración JSON
├── packages.sh         # Instalador de dependencias (Fedora/dnf)
└── assets/             # Imágenes y capturas de UI
```

## Instalación

Ver `install.sh` para instrucciones completas.

## Dependencias

Quickshell, Hyprland, cliphist+wl-clipboard, mpDris2 (MPRIS), PipeWire (audio nativo, con pactl/wpctl como fallback), NetworkManager, bluetoothctl/bluez, curl, Open-Meteo API.

Las métricas de sistema (CPU, RAM, disco, red, ventilador) se leen de forma
nativa vía QML `FileView` sobre `/proc` y `/sys` — ya no dependen de `dgop`
ni de un backend Python.
