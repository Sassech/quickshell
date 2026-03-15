#!/bin/bash
# ram-stats.sh — Estadísticas de uso de RAM en tiempo real

# Leer información de memoria desde /proc/meminfo
awk '/MemTotal:|MemAvailable:|MemFree:|Buffers:|Cached:|SwapTotal:|SwapFree:/ {
    if ($1 == "MemTotal:") mem_total = $2
    else if ($1 == "MemAvailable:") mem_avail = $2
    else if ($1 == "MemFree:") mem_free = $2
    else if ($1 == "Buffers:") buffers = $2
    else if ($1 == "Cached:") cached = $2
    else if ($1 == "SwapTotal:") swap_total = $2
    else if ($1 == "SwapFree:") swap_free = $2
}
END {
    # Calcular memoria usada (total - disponible)
    mem_used = mem_total - mem_avail
    # Calcular porcentaje de uso
    mem_percent = int((mem_used * 100) / mem_total)
    # Convertir a GB (redondeado a 1 decimal)
    mem_used_gb = mem_used / 1048576
    mem_total_gb = mem_total / 1048576
    mem_avail_gb = mem_avail / 1048576
    
    # Swap usado
    swap_used = swap_total - swap_free
    swap_percent = swap_total > 0 ? int((swap_used * 100) / swap_total) : 0
    
    # Output: porcentaje, usado en GB, total en GB, disponible en GB, swap porcentaje
    printf "%d\n%.1f\n%.1f\n%.1f\n%d\n", mem_percent, mem_used_gb, mem_total_gb, mem_avail_gb, swap_percent
}' /proc/meminfo
