package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

var (
	iconCachePath  = ""
	iconCache      = map[string]string{}
	iconCacheDirty = false

	iconSizes = []string{"256x256", "128x128", "96x96", "64x64", "48x48", "32x32"}
	iconCats  = []string{"apps", "categories", "devices", "mimetypes"}
	// iconThemes se completa en initTheme (detección de tema).
	iconThemes = []string{}
)

// homeDir cachea el home para evitar errores repetidos.
var homeDir = func() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return "/tmp"
	}
	return h
}()

func iconCacheFile() string {
	if iconCachePath == "" {
		iconCachePath = filepath.Join(homeDir, ".cache", "qs-icon-cache.json")
	}
	return iconCachePath
}

func loadIconCache() {
	data, err := os.ReadFile(iconCacheFile())
	if err != nil {
		iconCache = map[string]string{}
		return
	}
	if err := json.Unmarshal(data, &iconCache); err != nil {
		iconCache = map[string]string{}
	}
	if iconCache == nil {
		iconCache = map[string]string{}
	}
}

func saveIconCache() {
	if !iconCacheDirty {
		return
	}
	data, err := json.Marshal(iconCache)
	if err != nil {
		return
	}
	dir := filepath.Dir(iconCacheFile())
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return
	}
	tmp := iconCacheFile() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, iconCacheFile())
	iconCacheDirty = false
}

// detectTheme lee ~/.config/gtk-3.0/settings.ini buscando el tema de íconos.
func detectTheme() string {
	p := filepath.Join(homeDir, ".config", "gtk-3.0", "settings.ini")
	data, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "gtk-icon-theme-name=") {
			v := strings.TrimSpace(strings.TrimPrefix(line, "gtk-icon-theme-name="))
			if v != "" {
				return v
			}
		}
	}
	return ""
}

// initTheme arma la lista de temas candidatos: detectado primero, luego los
// clásicos, sin duplicados.
func initTheme() {
	if len(iconThemes) > 0 {
		return
	}
	detected := detectTheme()
	seen := map[string]bool{}
	for _, t := range append([]string{detected}, "hicolor", "Papirus", "Papirus-Dark", "breeze", "Adwaita") {
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		iconThemes = append(iconThemes, t)
	}
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// findIconPath replica find_icon_path con mejora de tema detectado.
func findIconPath(iconName string) string {
	if iconName == "" {
		return ""
	}
	if p, ok := iconCache[iconName]; ok {
		return p
	}
	if strings.HasPrefix(iconName, "/") && exists(iconName) {
		iconCache[iconName] = iconName
		iconCacheDirty = true
		return iconName
	}
	initTheme()
	roots := []string{"/usr/share/icons", filepath.Join(homeDir, ".local", "share", "icons")}
	for _, theme := range iconThemes {
		for _, size := range iconSizes {
			for _, cat := range iconCats {
				for _, ext := range []string{"png", "svg"} {
					for _, root := range roots {
						p := filepath.Join(root, theme, size, cat, iconName+"."+ext)
						if exists(p) {
							iconCache[iconName] = p
							iconCacheDirty = true
							return p
						}
					}
				}
			}
		}
	}
	// Fallback pixmaps (local primero, como el tema)
	pixRoots := []string{filepath.Join(homeDir, ".local", "share", "pixmaps"), "/usr/share/pixmaps"}
	for _, ext := range []string{"png", "svg", "xpm"} {
		for _, root := range pixRoots {
			p := filepath.Join(root, iconName+"."+ext)
			if exists(p) {
				iconCache[iconName] = p
				iconCacheDirty = true
				return p
			}
		}
	}
	iconCache[iconName] = ""
	iconCacheDirty = true
	return ""
}
