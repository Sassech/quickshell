# Overlays — Subsistema de Overlays Animados

Ventanas flotantes en esquinas (fade + slide) reutilizables, separadas de los
modales del sistema (`Modals/` raíz: NotificationPopup, ClockModal,
ClipboardModal, etc.) siguiendo el mismo criterio que `Modals/cc/` para el
Control Center.

## Estructura

```
Modals/overlays/
├── OverlayWindow.qml   # Plantilla base parametrizada (no tocar por instancia)
├── Watermark.qml       # Instancia concreta: estilo "Activar Windows"
└── PreviewOverlay.qml  # Instancia concreta: GIF decorativo
```

El registro de cada overlay (metadatos + estado) vive en
`Components/OverlayEntry.qml` y el estado centralizado en
`Components/OverlaysManager.qml` (ver «Gestión de overlays»).

## Plantilla — OverlayWindow.qml

`PanelWindow` anclado a una esquina, sin exclusión de espacio
(`ExclusionMode.Ignore`), con máscara recortada a la tarjeta y animación
fade + slide desde el borde.

### Parámetros

| Propiedad | Defecto | Descripción |
|---|---|---|
| `corner` | `"bottom-right"` | `bottom-right` \| `bottom-left` \| `top-right` \| `top-left` |
| `overlayWidth` | `320` | Ancho fijo de la tarjeta |
| `overlayHeight` | `0` | 0 = el contenido decide la altura |
| `bgColor` | `Theme.cardBg3` | Fondo de la tarjeta |
| `accent` | `Theme.accent` | Color de la franja lateral de acento |
| `showAccent` | `true` | Muestra la franja lateral (false = solo texto, p. ej. watermark) |
| `restingOpacity` | `0.9` | Opacidad final tras el fade-in |
| `animInMs` / `animOutMs` | `300` / `300` | Duración de entrada / salida |
| `autoHideMs` | `0` | 0 = queda visible hasta `hide()`; >0 = auto-oculta |
| `onTop` | `true` | true = capa Overlay (sobre todas las ventanas); false = capa Bottom (queda debajo de las ventanas maximizadas) |
| `topOffset` / `bottomOffset` / `leftOffset` / `rightOffset` | `0` | Px extra sobre el margen base de 16px del corner elegido (empujan hacia adentro) |
| `mouseThrough` | `false` | true = los clicks pasan a la ventana de abajo (overlays decorativos); false = solo la tarjeta es clickeable |
| `entryId` | `""` | id de la entrada en `OverlaysManager`; si se setea, el template auto-gobierna la visibilidad (visible al arrancar si está habilitado + reacción en vivo al toggle). Vacío = el overlay maneja `show()`/`hide()` manualmente |

### API

- `show()` — hace visible y corre fade+slide de entrada (reinicia auto-hide).
- `hide()` — corre la animación de salida y oculta al terminar.

### Contenido

Los hijos declarados dentro de un overlay concreto aterrizan automáticamente
en `contentArea` vía la *default property* (`default property alias content`).
El overlay concreto NO hereda ni toca la plantilla: solo declara su UI.

## Colores: no depender de Theme.qml

Los overlays NO deben usar `Theme.text`, `Theme.muted2` ni otros colores de
`Theme.qml` para su contenido. Razones:

- `Theme.qml` se **regenera en cada cambio de wallpaper** (`wallpaper-set.sh`
  lo reescribe); un overlay que herede esos colores cambia de look sin aviso.
- Cada overlay puede necesitar **tonos o identidad propios** (agresivo,
  discreto, corporativo, estado crítico…).
- Los overlays flotan sobre el wallpaper (a veces video), así que la
  legibilidad depende de contraste fijo, no del tema del momento.

Convención:

1. Cada overlay concreto declara **sus propios colores** (hex, `Qt.rgba`,
   blanco/negro con alpha) directamente en su contenido.
2. Si un color debe ser configurable desde afuera, exponerlo como `property`
   del overlay concreto (nunca leer `Theme.*` en el cuerpo del contenido).
3. `OverlayWindow` sí usa `Theme.cardBg3`/`Theme.accent` como **defaults** de
   la plantilla, pero el overlay concreto puede sobreescribirlos
   (`bgColor`, `accent`), como hace `Watermark` con `bgColor: "transparent"`.
4. Para legibilidad sobre cualquier fondo, preferir blanco translúcido con
   contorno (`style: Text.Outline; styleColor: "black"`) o un color fijo con
   opacidad controlada, en vez de heredar el color del tema.

## Crear un overlay nuevo

```qml
// qmllint disable uncreatable-type
import QtQuick

MyOverlay {
    entryId:        "myOverlay"   // el template auto-gobierna la visibilidad
                                  // (arranque + reacción al toggle, sin boilerplate)
    corner:         "top-right"
    overlayWidth:   280
    autoHideMs:     0
    onTop:          OverlaysManager.get("myOverlay").onTop
    // mouseThrough: true  // si es decorativo (sin interacción), para que los
                          // clicks pasen a la ventana de abajo

    // Contenido → contentArea automáticamente.
    // Colores propios del overlay, NO Theme.*
    Row {
        Text {
            text: "Aviso"
            color: "white"
            style: Text.Outline
            styleColor: "black"
            opacity: 0.8
        }
    }
}
```

Guardarlo en `Modals/overlays/`, declarar el `OverlayEntry` correspondiente en
`OverlaysManager.overlays` y definir su id en `entryId`. Al usar `entryId`,
el template centraliza la visibilidad (visible al arrancar si está habilitado
+ sincronización en vivo del toggle); no hace falta escribir `visible`,
`Component.onCompleted` ni `Connections` a mano. Si el overlay necesita
control manual de `show()`/`hide()` (p. ej. threshold, como NotificationPopup),
dejar `entryId` vacío y exponer funciones que llamen a `root.show()` / `root.hide()`.
Instanciarlo por monitor en `shell.qml` con
`Variants { model: Quickshell.screens }` (mismo patrón que el resto).

## Conectar un trigger

Los overlays **data-driven** (con `entryId`) no necesitan trigger: el template
los muestra automáticamente cuando su `OverlayEntry` está habilitado y reacciona
al toggle en vivo desde `OverlaysControl` (o escribiendo el estado). Solo los
overlays **no manejados** (con `entryId` vacío) controalan su visibilidad a mano.

Para controlar un overlay no manejado desde otro componente (p. ej. un botón en
el Control Center), exponer funciones públicas y llamarlas con contexto:

```qml
// En el overlay concreto: quedar visibles para shell.qml
function showOverlay() { root.show() }
function hideOverlay() { root.hide() }
```

```qml
// En shell.qml, desde cualquier componente: overlayInst.showOverlay()
// o el patrón FIFO + broadcast* existente si se quiere disparar desde un
// script/keybind (ver el mecanismo usado por clipboard/overview con FifoChannel).
```

## Gestión de overlays (OverlaysManager + OverlaysControl)

Enfoque **data-driven**: cada overlay es una entrada `OverlayEntry` en la lista
`OverlaysManager.overlays`. El modal (OverlaysControl) renderiza una fila por
entrada y los overlays leen su estado con `OverlaysManager.get("id")`. Agregar
un overlay nuevo NO toca ni el modal ni `shell.qml`.

- `Components/OverlayEntry.qml` — registro de un overlay: `entryId` (único,
  usado para persistencia y lookup), `name`, `description`, `icon`, `source`
  (ruta al .qml que lo instancia), y estado `enabled`/`onTop` (persistido).
- `Components/OverlaysManager.qml` — singleton con la lista `overlays` y
  `function get(id)`. Persiste el estado de todas las entradas en
  `config/overlays-state.json` (`{"overlays": [{id, enabled, onTop}]}`),
  con carga al arranque (fallback a defaults) y guardado solo tras cargar
  (`_loaded`) y solo ante cambios (`enabledChanged`/`onTopChanged`).
- `Modals/OverlaysControl.qml` — modal del sistema (NO un overlay flotante)
  que renderiza un switch de visibilidad y un switch de capa por entrada del
  manager (Repeater sobre `overlays`).

Agregar un overlay nuevo:

1. Crear su `.qml` en `Modals/overlays/` (basado en `OverlayWindow`).
2. Declarar `entryId`, `corner`, `overlayWidth` y offsets. `entryId` hace que
   el template auto-gobierne **visibilidad y capa** (deriva `onTop` del entry),
   así que no hay que escribir `visible` / `Component.onCompleted` /
   `Connections` / `onTop` a mano. Si es decorativo (sin interacción), activar
   `mouseThrough: true` para que los clicks pasen a la ventana de abajo.
3. Agregar su `OverlayEntry` a `OverlaysManager.overlays`.
4. Instanciarlo por monitor en `shell.qml` con
   `Variants { model: Quickshell.screens }` (mismo patrón que el resto).

> Nota de imports: los archivos dentro de `Modals/overlays/` importan
> `"../../Components"` (dos niveles), NO `"../Components"` — esa ruta no existe.
>
> Nota de arranque: los `OverlayEntry` arrancan con defaults (`enabled: true`,
> `onTop: true`) y `OverlaysManager.loadProc` aplica el JSON persistido de forma
> asíncrona justo después de instanciarse. En el primer frame un overlay puede
> verse en `Overlay` y luego moverse a `Bottom` (o viceversa) si el estado
> guardado difiere — un fogonazo de capa cosmético e inofensivo (no compite con
> la barra, que vive en `Layer.Top`). No requiere fix.
