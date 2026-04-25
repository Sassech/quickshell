#!/bin/bash
# ram-detail.sh — Información detallada de RAM
set -euo pipefail
IFS=$'\n\t'

awk '/MemTotal:|MemFree:|MemAvailable:|Buffers:|Cached:|SwapCached:|Active:|Inactive:|Active\(anon\):|Inactive\(anon\):|Active\(file\):|Inactive\(file\):|Dirty:|Writeback:|AnonPages:|Mapped:|Shmem:|SwapTotal:|SwapFree:|SReclaimable:|SUnreclaim:/ {
    gsub(/:/, "", $1)
    mem[$1] = $2
}
END {
    # Calcular valores derivados
    mem_total = mem["MemTotal"]
    mem_free = mem["MemFree"]
    mem_avail = mem["MemAvailable"]
    mem_used = mem_total - mem_avail
    mem_percent = int((mem_used * 100) / mem_total)
    
    buffers = mem["Buffers"]
    cached = mem["Cached"]
    swap_cached = mem["SwapCached"]
    active = mem["Active"]
    inactive = mem["Inactive"]
    
    swap_total = mem["SwapTotal"]
    swap_free = mem["SwapFree"]
    swap_used = swap_total - swap_free
    swap_percent = swap_total > 0 ? int((swap_used * 100) / swap_total) : 0
    
    anon_pages = mem["AnonPages"]
    mapped = mem["Mapped"]
    shmem = mem["Shmem"]
    dirty = mem["Dirty"]
    writeback = mem["Writeback"]
    
    sreclaimable = mem["SReclaimable"]
    sunreclaim = mem["SUnreclaim"]
    slab_total = sreclaimable + sunreclaim
    
    # Output en formato clave:valor (convertir a MB)
    print "MEM_TOTAL:" int(mem_total / 1024)
    print "MEM_USED:" int(mem_used / 1024)
    print "MEM_FREE:" int(mem_free / 1024)
    print "MEM_AVAIL:" int(mem_avail / 1024)
    print "MEM_PERCENT:" mem_percent
    print "BUFFERS:" int(buffers / 1024)
    print "CACHED:" int(cached / 1024)
    print "SWAP_CACHED:" int(swap_cached / 1024)
    print "ACTIVE:" int(active / 1024)
    print "INACTIVE:" int(inactive / 1024)
    print "SWAP_TOTAL:" int(swap_total / 1024)
    print "SWAP_USED:" int(swap_used / 1024)
    print "SWAP_FREE:" int(swap_free / 1024)
    print "SWAP_PERCENT:" swap_percent
    print "ANON_PAGES:" int(anon_pages / 1024)
    print "MAPPED:" int(mapped / 1024)
    print "SHMEM:" int(shmem / 1024)
    print "DIRTY:" int(dirty / 1024)
    print "WRITEBACK:" int(writeback / 1024)
    print "SLAB:" int(slab_total / 1024)
    print "SRECLAIMABLE:" int(sreclaimable / 1024)
    print "SUNRECLAIM:" int(sunreclaim / 1024)
}' /proc/meminfo
