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

// updates-check: detecta dnf/apt/pacman/snap/flatpak (LookPath), cuenta updates,
// cachea ~/.cache/qs-helper/updates.json 1h. Exit 0 si hay datos, 1 solo si fallan todos (JSON error).

type updatesResult struct {
	Total     int            `json:"total"`
	Managers  map[string]int `json:"managers"`
	CheckedAt string         `json:"checkedAt"`
	Error     string         `json:"error"`
}

const updatesCacheTTL = time.Hour

// updatesLockPath: serializa chequeo entre overlays (flock).
var updatesLockPath = filepath.Join(cacheDir, ".updates.lock")

// lockUpdates: flock exclusivo → release().
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

// runCmd: ejecuta con timeout, devuelve stdout+code (-1 timeout/fallo); stderr descartado.
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

// countLines: líneas no vacías.
func countLines(data []byte) int {
	n := 0
	for _, l := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(l) != "" {
			n++
		}
	}
	return n
}

// countLinesSkipPrefix: salta encabezados por prefijo.
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

// mgrCheck: descriptor gestor.
type mgrCheck struct {
	name  string
	bin   string
	args  []string
	count func(out []byte, code int) (int, bool) // (n, ok); ok=false → error
}

// checkUpdates: consulta gestores instalados → conteos+errores.
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

// buildUpdatesResult: arma JSON.
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

// runUpdatesCheck: fast path cache fresco, slow path lock+chequeo.
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
