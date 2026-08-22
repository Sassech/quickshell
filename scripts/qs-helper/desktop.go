package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// appInfo replica el dict retornado por parse_desktop.
type appInfo struct {
	Name     string `json:"name"`
	Exec     string `json:"exec"`
	Icon     string `json:"icon"`
	Generic  string `json:"generic"`
	Keywords string `json:"keywords"`
}

var (
	reNoDisplay  = regexp.MustCompile(`(?m)^NoDisplay=true`)
	reHidden     = regexp.MustCompile(`(?m)^Hidden=true`)
	reName       = regexp.MustCompile(`(?m)^Name=(.+)$`)
	reExec       = regexp.MustCompile(`(?m)^Exec=(.+)$`)
	reIcon       = regexp.MustCompile(`(?m)^Icon=(.+)$`)
	reGeneric    = regexp.MustCompile(`(?m)^GenericName=(.+)$`)
	reKeywords   = regexp.MustCompile(`(?m)^Keywords=(.+)$`)
	reFieldCodes = regexp.MustCompile(`%[a-zA-Z]`)
)

// desktopEntrySection extrae solo el bloque [Desktop Entry] del contenido para
// que todos los regex de parseo (NoDisplay/Hidden/Name/Exec/Icon/Generic/...)
// se apliquen únicamente sobre la sección correcta y no se contaminen con otras
// secciones ([Desktop Action] y similares).
//
// Devuelve "" si el archivo no define [Desktop Entry]; parseDesktop lo descarta
// porque ningún regex matchea sobre un bloque vacío.
func desktopEntrySection(content string) string {
	// Descarta BOM y normaliza CRLF a LF para simplificar el corte de sección.
	content = strings.ReplaceAll(strings.TrimPrefix(content, "\ufeff"), "\r\n", "\n")
	var sb strings.Builder
	cont := false // la línea anterior termina en '\' (valor continuado)
	for _, line := range strings.Split(content, "\n") {
		if line == "[Desktop Entry]" {
			sb.WriteString(line)
			sb.WriteByte('\n')
			cont = false
			continue
		}
		if sb.Len() == 0 {
			continue // aún no llegamos a la sección
		}
		// Fin de sección: primer '[' al inicio de línea que NO sea una
		// continuación, para no partir una línea continuada (finaliza en '\').
		if strings.HasPrefix(line, "[") && !cont {
			break
		}
		sb.WriteString(line)
		sb.WriteByte('\n')
		cont = strings.HasSuffix(line, "\\")
	}
	return sb.String()
}

// parseDesktop lee un archivo .desktop y retorna appInfo, o nil si debe ocultarse.
func parseDesktop(path string) *appInfo {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	content := string(data)
	entrySection := desktopEntrySection(content)
	if reNoDisplay.MatchString(entrySection) || reHidden.MatchString(entrySection) {
		return nil
	}
	nameM := reName.FindStringSubmatch(entrySection)
	execM := reExec.FindStringSubmatch(entrySection)
	if len(nameM) < 2 || len(execM) < 2 {
		return nil
	}
	info := &appInfo{
		Name: strings.TrimSpace(nameM[1]),
		Exec: strings.TrimSpace(reFieldCodes.ReplaceAllString(strings.TrimSpace(execM[1]), "")),
	}
	if m := reIcon.FindStringSubmatch(entrySection); len(m) > 1 {
		info.Icon = strings.TrimSpace(m[1])
	}
	if m := reGeneric.FindStringSubmatch(entrySection); len(m) > 1 {
		info.Generic = strings.TrimSpace(m[1])
	}
	if m := reKeywords.FindStringSubmatch(entrySection); len(m) > 1 {
		info.Keywords = strings.TrimSpace(m[1])
	}
	return info
}

// appDirs replica APP_DIRS del Python.
func appDirs() []string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "~"
	}
	return []string{
		"/usr/share/applications",
		filepath.Join(home, ".local/share/applications"),
	}
}

// appCacheFile es la ruta del cache de apps en disco. Nombre v2: invalida el
// cache v1 (qs-spotlight-apps.json) que quedó envenenado con objetos vacíos
// por los campos sin tags JSON.
var appCacheFile = filepath.Join(homeDir, ".cache", "qs-spotlight-apps-v2.json")

// appCache es la estructura serializada al disco.
type appCache struct {
	Mtime int64     `json:"mtime"` // unix timestamp del dir más reciente
	Apps  []appInfo `json:"apps"`
}

// cachedScanApps retorna la lista de apps desde cache en disco si los dirs no
// cambiaron (mtime), o re-escanea y actualiza el cache en caso contrario.
func cachedScanApps() []appInfo {
	dirs := appDirs()

	// Calcular mtime máximo de los dirs monitoreados.
	var maxMtime int64
	for _, d := range dirs {
		if info, err := os.Stat(d); err == nil {
			if t := info.ModTime().Unix(); t > maxMtime {
				maxMtime = t
			}
		}
	}

	// Intentar leer cache existente.
	if data, err := os.ReadFile(appCacheFile); err == nil {
		var c appCache
		if json.Unmarshal(data, &c) == nil && c.Mtime == maxMtime && len(c.Apps) > 0 {
			return c.Apps
		}
	}

	// Cache miss o stale → re-escanear y persistir.
	apps := scanApps()
	c := appCache{Mtime: maxMtime, Apps: apps}
	if data, err := json.Marshal(c); err == nil {
		_ = os.MkdirAll(filepath.Dir(appCacheFile), 0o755)
		tmp := appCacheFile + ".tmp"
		if os.WriteFile(tmp, data, 0o644) == nil {
			_ = os.Rename(tmp, appCacheFile)
		}
	}
	return apps
}

// scanApps recorre los dirs de aplicaciones y devuelve apps únicas por nombre
// (el primer dir gana), igual que el modo --list-apps del Python.
func scanApps() []appInfo {
	seen := map[string]bool{}
	apps := []appInfo{}
	for _, d := range appDirs() {
		entries, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() || filepath.Ext(e.Name()) != ".desktop" {
				continue
			}
			info := parseDesktop(filepath.Join(d, e.Name()))
			if info == nil || seen[info.Name] {
				continue
			}
			seen[info.Name] = true
			apps = append(apps, *info)
		}
	}
	return apps
}
