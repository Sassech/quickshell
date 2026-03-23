# Especificación: Modal de Teclado e Idioma (listas dinámicas + buscador)

## Resumen
Actualizar el modal de “Teclado e Idioma” para que cargue layouts y locales reales del sistema, con buscadores separados por pestaña, manteniendo un fallback a listas curadas si faltan comandos del sistema. La barra inferior seguirá mostrando el layout/locale actual y el modal permitirá cambiar ambos con feedback claro.

## Alcance
- Cambios en `LanguageModal.qml` para UX y lógica de datos.
- `LanguageWidget.qml` se mantiene salvo que haga falta alinear el formato mostrado.
- Sin nuevos servicios externos.

## UX/Flujo
- Modal con dos pestañas: **Teclado** e **Idioma**.
- Cada pestaña tiene su buscador y lista desplazable.
- Sección “Favoritos” opcional arriba y “Todos” debajo; si no hay favoritos, se oculta.
- Elemento activo destacado con banda lateral + chip “Actual”.
- Click directo aplica el cambio y actualiza el estado mostrado.

## Datos y fuentes
- **Layouts:** `localectl list-keymaps`.
- **Layout actual:** `hyprctl devices -j` → `active_keymap`.
- **Locales:** `localectl list-locales`.
- **Locale actual:** `localectl status` → `System Locale` (extraer `LANG=...`).
- Carga inicial al abrir el modal; filtrar en memoria local.

## Lógica de filtrado
- Se mantiene una lista completa en memoria (layouts/locales) y una lista de favoritos (opcional).
- El buscador filtra por substring (case-insensitive).
- Si no hay coincidencias, mostrar mensaje “No encontrado” y botón “Mostrar todo”.

## Comportamiento y acciones
- **Cambiar layout:** `hyprctl keyword input:kb_layout <code>` y `hyprctl dispatch switchxkblayout all 0` (aplica global).
- **Cambiar locale:** `localectl set-locale LANG=<value>`.
- Tras aplicar, refrescar el estado actual en el modal.

## Manejo de errores y permisos
- Si `localectl` no existe o falla: usar lista curada actual como fallback y mostrar aviso “lista limitada”.
- Si `localectl set-locale` falla por permisos: mostrar mensaje “requiere privilegios” sin bloquear la UI.
- Si `hyprctl` falla: mantener último estado y reintentar al abrir.

## Rendimiento
- Evitar re-ejecutar comandos en cada cambio de búsqueda.
- Reconsultar solo al abrir el modal o al aplicar cambios.

## Integración con el resto del sistema
- El modal seguirá activándose desde `BottomBar.qml` y `shell.qml` sin cambios de interfaz pública.
- La barra inferior puede refrescarse por el polling ya existente.

## Pruebas manuales
- Abrir modal en ambas pestañas.
- Buscar términos parciales y verificar filtrado.
- Aplicar layout y verificar que el widget de barra inferior cambia.
- Aplicar locale y verificar `localectl status`.
- Simular fallo de `localectl` y confirmar fallback.

## Fuera de alcance
- Persistencia avanzada de favoritos en archivo de configuración.
- Internacionalización de textos (se mantiene en español).

## Detalles definidos para implementación

### Fallback (lista curada)
Si `localectl` falla, se usa exactamente la lista curada actual de `LanguageModal.qml` (layouts/locales). Es una única fuente de respaldo, mantenida manualmente en el modal.

### Favoritos
Por defecto, no hay favoritos persistidos. Se puede inicializar con una lista estática dentro del modal (ej. `es`, `us`, `gb`, `de`) y ocultar la sección si queda vacía. No se guarda preferencia del usuario en disco.

### Formato de display vs valor
- **Layouts:** valor real = código (ej. `us`, `es`, `latam`).
- **Label:** si el código existe en la lista curada, usar su etiqueta; si no, mostrar el código en mayúsculas como etiqueta de respaldo.
- **Locales:** valor real = `en_US.UTF-8` (completo). Label = valor completo, con un alias corto si coincide con lista curada.

### Marcado de “Actual”
- **Layout actual:** usar `hyprctl devices -j` y seleccionar el teclado **principal** si existe (`main: true`); si no, usar el primer teclado del listado. Tomar su `active_keymap` y comparar por substring contra el código (lowercase). Si no coincide con ningún código, no se marca como actual.
- **Locale actual:** parsear `LANG=...` desde `System Locale` y comparar contra el valor completo (y contra el prefijo antes del punto para tolerar variantes).

### Parseo recomendado
- `localectl status | awk -F'LANG=' '/System Locale/{print $2}' | awk '{print $1}'` para extraer `LANG`.
- `localectl list-locales` y `localectl list-keymaps` con timeout corto (2–3s) y captura de error.

### Permisos
No se intentará elevar privilegios. Si `localectl set-locale` falla, se informa y no se reintenta con `sudo`/`pkexec`.

### Comportamiento con `localectl` no disponible
- Se muestra la lista curada, pero los items de locale quedan deshabilitados.
- Se muestra aviso “localectl no disponible” y el click no dispara cambios.
