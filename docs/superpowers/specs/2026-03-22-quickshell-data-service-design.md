# Quickshell Data Service (QDS) - Design Specification

**Date:** 2026-03-22
**Status:** Draft
**Related Project:** Quickshell Desktop Shell Configuration

## 1. Overview

The Quickshell Data Service (QDS) is a Rust-based background service designed to centralize system data acquisition and exposure for the Quickshell desktop shell. It replaces the current pattern where each widget independently polls system resources or calls external scripts/APIs, improving performance, maintainability, and code reuse.

## 2. Architecture

### 2.1 High-Level Design

QDS runs as a long-lived systemd user service. It leverages Rust's performance and safety guarantees to efficiently poll system metrics, query external APIs, and aggregate data. Data is exposed to QML widgets via D-Bus, using a hybrid property/signal model for efficient IPC.

```
[QML Widgets] <--(D-Bus)--> [QDS Backend (Rust)]
                                      |
                       +---------------+---------------+
                       |               |               |
                 [System APIs]   [External APIs]  [File System]
                 (sysinfo, ...)  (Open-Meteo)     (/proc, /sys)
```

### 2.2 Core Components

*   **D-Bus Service Layer:** Handles D-Bus registration, method calls, property exposure, and signal emission.
*   **Data Manager:** Orchestrates data fetching, caching, and retry logic. Central hub for all modules.
*   **Data Modules:** Independent modules responsible for fetching specific types of data (CPU, Weather, etc.).
*   **Configuration:** Handles startup configuration and user preferences (polling intervals, API keys, etc.).

## 3. Data Sources & Modules

QDS will implement the following modules:

1.  **System Metrics:** CPU (usage, temperature), RAM/Swap, GPU, Disk, Network (speeds, status), Battery.
2.  **External Data:** Weather (Open-Meteo API), Geolocation (Geoclue2).
3.  **Desktop Integration:** Clipboard (cliphist), Audio (PipeWire/PulseAudio via libpulse), Bluetooth, Media Player (MPRIS2).
4.  **Time/Date:** Local time, timezone, locale-specific formatting.

## 4. D-Bus Interface

QDS will expose a single D-Bus service named `com.Quickshell.DataService`.

### 4.1 Object Path Structure

```
/com/Quickshell/DataService
├── /com/Quickshell/DataService/Cpu
├── /com/Quickshell/DataService/Memory
├── /com/Quickshell/DataService/Weather
├── /com/Quickshell/DataService/Clipboard
└── ...
```

### 4.2 Interface Patterns

Each sub-object (e.g., `/Cpu`) will implement:

*   **`org.freedesktop.DBus.Properties`**: For reading current values (ReadOnly properties).
*   **Custom Signals**: For push-based updates (e.g., `Updated`).

**Example: `/Cpu` Interface**

| Property | Type | Description |
|----------|------|-------------|
| `UsagePercent` | `u32` | CPU usage percentage (0-100). |
| `Temperature` | `i32` | CPU temperature in Celsius (if available), or -1. |

**Signal:** `Changed` (emitted when values update).

### 4.3 QML Integration

QML widgets will use `QtQml` to interface with D-Bus.

```qml
import QtQml 2.2
import DBusConnector 1.0 // Custom QML wrapper for D-Bus

DBusConnector {
    id: dbus
    service: "com.Quickshell.DataService"
    path: "/com/Quickshell/DataService/Cpu"
    interface: "com.Quickshell.DataService.Cpu"

    property int cpuPercent: getProperty("UsagePercent")
    property int cpuTemp: getProperty("Temperature")

    onPropertyChanged: {
        // Update local QML properties
    }
}
```

*Note: A thin QML wrapper around `QDBusInterface` will be implemented in the QDS project or provided as a utility to simplify D-Bus access in QML.*

## 5. Polling & Update Strategy

*   **Adaptive Polling:** QDS will implement smart polling intervals. High-frequency data (CPU, Network speed) may poll every 1-2 seconds, while low-frequency data (Weather) may poll every 10-30 minutes.
*   **Event-Driven Updates:** Where possible, QDS will listen to system events (e.g., battery level change, network status change) to trigger updates immediately, rather than relying solely on polling.

## 6. Error Handling & Caching

*   **Fail-Safe Caching:** All modules will cache their last known valid data in memory and optionally to disk (for persistence across restarts).
*   **Graceful Degradation:** If a source fails (e.g., API unreachable), the module returns the cached value and sets a timestamp/flag indicating stale data.
*   **Retry Logic:** Failed requests will be retried with exponential backoff (starting at 1s, max 5min).
*   **Error Properties:** Each module will expose an `Error` or `Status` property to inform clients of health issues.

## 7. Deployment

*   **Binary:** Rust binary compiled for the target architecture.
*   **Service:** Systemd user service (`quickshell-data.service`).
*   **Installation:** `cargo build --release`, copy binary to `$HOME/.local/bin/`, symlink or install systemd unit.
*   **Auto-start:** Enabled via systemd user session.

## 8. Security

*   **API Keys:** Weather API (Open-Meteo) is keyless. If keys are required for future services, they will be stored in a secure config file (e.g., `~/.config/quickshell/qds.conf`).
*   **Sandboxing:** QDS will run with minimal privileges required to read system metrics. It will not require root access.

## 9. Implementation Plan (High-Level)

1.  **Project Setup:** Initialize Rust project (`cargo new quickshell-data-service`), set up D-Bus dependencies (`zbus` or `dbus-rs`).
2.  **Core D-Bus Skeleton:** Implement basic D-Bus service registration and simple property exposure.
3.  **Module Implementation:** Implement modules one by one (CPU → Memory → Weather, etc.), integrating system APIs and external HTTP clients.
4.  **QML Integration:** Create QDS and update existing QML widgets to use D-Bus instead of `Process` scripts.
5.  **Testing:** Unit tests for modules, integration tests for D-Bus communication.
6.  **Deployment:** Build binary, create systemd unit, document usage.

## 10. Trade-offs & Alternatives Considered

*   **Python vs. Rust:** Chosen Rust for superior performance, memory safety, and native D-Bus support, despite higher initial learning curve.
*   **HTTP Server vs. D-Bus:** Chosen D-Bus for tighter OS integration, lower latency compared to localhost HTTP, and standard desktop IPC pattern.
*   **C++/Qt Plugin:** Rejected in favor of external Rust service for better separation of concerns and easier independent updates.
