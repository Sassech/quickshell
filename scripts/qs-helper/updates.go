package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

// ── Comprobación de actualizaciones del sistema (updates-check) ─────────────
// Detecta los gestores de paquetes instalados (dnf/apt/pacman/snap/flatpak) en
// runtime con exec.LookPath y cuenta las actualizaciones disponibles de cada
// uno. El resultado se cachea en ~/.cache/qs-helper/updates.json con TTL de 1h
// para que la shell pueda consultarlo seguido sin martillar los gestores.
//
// Semántica de salida: exit 0 siempre que haya datos (aunque haya updates);
// exit 1 solo en fallo real (cache vencido/ausente y todos los gestores
// presentes fallaron). En ese caso el JSON lleva el campo "error".

type updatesResult struct {
	Total     int            `json:"total"`
	Managers  map[string]int `json:"managers"`
	CheckedAt string         `json:"checkedAt"`
	Error     string         `json:"error"`
}

const updatesCacheTTL = time.Hour

// updatesLockPath serializa el chequeo entre instancias (un overlay por
// pantalla): solo un proceso corre dnf/flatpak a la vez, el resto espera y
// lee del cache fresco.
var updatesLockPath = filepath.Join(cacheDir, ".updates.lock")

// lockUpdates adquiere un lock exclusivo; devuelve la función que lo libera.
func lockUpdates() (release func()) {
	_ = os.MkdirAll(cacheDir, 0o755)
	f, err := os.OpenFile(updatesLockPath, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return func() {
			// Sin lockfile no hay lock: no-op deliberado (best-effort, cada
			// instancia consultará los gestores por su cuenta).
		}
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		_ = f.Close()
		return func() {
			// Flock falló (p.ej. FS sin soporte): no-op deliberado; el
			// chequeo sigue sin serializar entre instancias.
		}
	}
	return func() {
		_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
		_ = f.Close()
	}
}

// runCmd ejecuta un comando con timeout (los gestores pueden tardar en
// refrescar metadatos). Devuelve stdout y el código de salida; -1 si no pudo
// ejecutarse o se agotó el tiempo. stderr se descarta (ruido de los gestores).
func runCmd(timeout time.Duration, name string, args ...string) ([]byte, int) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return out.Bytes(), ee.ExitCode()
		}
		return nil, -1
	}
	return out.Bytes(), 0
}

// countLines cuenta líneas no vacías de la salida.
func countLines(data []byte) int {
	n := 0
	for _, l := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(l) != "" {
			n++
		}
	}
	return n
}

// countLinesSkipPrefix cuenta líneas no vacías que no empiecen con el prefijo
// (salta encabezados tipo "Listing..." de apt o la fila de títulos de snap).
func countLinesSkipPrefix(data []byte, prefix string) int {
	n := 0
	for _, l := range strings.Split(string(data), "\n") {
		t := strings.TrimSpace(l)
		if t != "" && !strings.HasPrefix(t, prefix) {
			n++
		}
	}
	return n
}

// mgrCheck describe cómo consultar un gestor de paquetes.
type mgrCheck struct {
	name  string
	bin   string
	args  []string
	count func(out []byte, code int) (int, bool) // (n, ok); ok=false → error
}

// checkUpdates consulta cada gestor instalado y devuelve el conteo por gestor
// más los errores por gestor (no fatales salvo que falle todas).
func checkUpdates() (map[string]int, []string) {
	checks := []mgrCheck{
		{
			// dnf: exit 100 = hay actualizaciones (convención de dnf), 0 = no.
			name: "dnf", bin: "dnf", args: []string{"check-update", "-q"},
			count: func(out []byte, code int) (int, bool) {
				switch code {
				case 100:
					return countLines(out), true
				case 0:
					return 0, true
				}
				return 0, false
			},
		},
		{
			// apt: lista de paquetes actualizables; se salta la cabecera.
			name: "apt", bin: "apt", args: []string{"list", "--upgradable"},
			count: func(out []byte, code int) (int, bool) {
				return countLinesSkipPrefix(out, "Listing"), code == 0
			},
		},
		{
			// pacman (checkupdates): una línea por paquete.
			name: "pacman", bin: "checkupdates",
			count: func(out []byte, code int) (int, bool) {
				return countLines(out), code == 0
			},
		},
		{
			// snap: refresh --list imprime cabecera + filas de paquetes.
			name: "snap", bin: "snap", args: []string{"refresh", "--list"},
			count: func(out []byte, code int) (int, bool) {
				return countLinesSkipPrefix(out, "Name"), code == 0
			},
		},
		{
			// flatpak: una línea por aplicación/ref con update.
			name: "flatpak", bin: "flatpak", args: []string{"remote-ls", "--updates"},
			count: func(out []byte, code int) (int, bool) {
				return countLines(out), code == 0
			},
		},
	}

	managers := map[string]int{}
	var errs []string
	var mu sync.Mutex
	var wg sync.WaitGroup
	for _, c := range checks {
		if _, err := exec.LookPath(c.bin); err != nil {
			continue // gestor no instalado → no se consulta
		}
		wg.Add(1)
		go func(c mgrCheck) {
			defer wg.Done()
			out, code := runCmd(30*time.Second, c.bin, c.args...)
			mu.Lock()
			defer mu.Unlock()
			if code == -1 {
				errs = append(errs, c.name+": no se pudo ejecutar "+c.bin)
				return
			}
			if n, ok := c.count(out, code); ok {
				managers[c.name] = n
			} else {
				errs = append(errs, fmt.Sprintf("%s: salida %d", c.name, code))
			}
		}(c)
	}
	wg.Wait()
	return managers, errs
}

// buildUpdatesResult compone el JSON de salida a partir del chequeo.
func buildUpdatesResult(managers map[string]int, errs []string) ([]byte, error) {
	total := 0
	for _, n := range managers {
		total += n
	}
	r := updatesResult{
		Total:     total,
		Managers:  managers,
		CheckedAt: time.Now().Format(time.RFC3339),
	}
	if len(errs) > 0 {
		r.Error = strings.Join(errs, "; ")
	}
	return json.Marshal(r)
}

// runUpdatesCheck implementa `updates-check`.
// Fast path: cache fresco → se imprime sin tocar los gestores.
// Slow path: lock (serializa instancias) + relectura + chequeo fresco.
func runUpdatesCheck() int {
	if data, ok := cacheRead("updates", updatesCacheTTL); ok {
		fmt.Println(string(data))
		return 0
	}

	release := lockUpdates()
	defer release()
	if data, ok := cacheRead("updates", updatesCacheTTL); ok {
		fmt.Println(string(data))
		return 0
	}

	managers, errs := checkUpdates()
	if len(managers) == 0 && len(errs) > 0 {
		// Fallo real: todos los gestores presentes fallaron y no hay cache.
		out, _ := json.Marshal(updatesResult{
			Total:     0,
			Managers:  map[string]int{},
			CheckedAt: time.Now().Format(time.RFC3339),
			Error:     "todos los gestores de paquetes fallaron: " + strings.Join(errs, "; "),
		})
		fmt.Println(string(out))
		return 1
	}

	out, err := buildUpdatesResult(managers, errs)
	if err != nil {
		fmt.Fprintf(os.Stderr, "updates-check: %v\n", err)
		return 1
	}
	cacheWrite("updates", out)
	fmt.Println(string(out))
	return 0
}
