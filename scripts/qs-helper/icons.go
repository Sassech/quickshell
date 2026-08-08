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

// homeDir se resuelve una vez al arrancar.
var homeDir = func() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return os.TempDir()
	}
	return h
}()

var (
	iconRoots = []string{
		"/usr/share/icons",
		filepath.Join(homeDir, ".local", "share", "icons"),
	}
	pixRoots = []string{
		filepath.Join(homeDir, ".local", "share", "pixmaps"),
		"/usr/share/pixmaps",
	}
	iconExts    = []string{"png", "svg"}
	iconPixExts = []string{"png", "svg", "xpm"}
)

// iconSlots precomputa las combinaciones (size, cat, ext, root) de la
// búsqueda por temas, para aplanar los loops anidados de findInThemes.
var iconSlots = func() [][4]string {
	slots := [][4]string{}
	for _, size := range iconSizes {
		for _, cat := range iconCats {
			for _, ext := range iconExts {
				for _, root := range iconRoots {
					slots = append(slots, [4]string{size, cat, ext, root})
				}
			}
		}
	}
	return slots
}()

// pixSlots precomputa las combinaciones (ext, root) del fallback pixmaps.
var pixSlots = func() [][2]string {
	slots := [][2]string{}
	for _, ext := range iconPixExts {
		for _, root := range pixRoots {
			slots = append(slots, [2]string{ext, root})
		}
	}
	return slots
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
		return cacheIcon(iconName, iconName)
	}
	initTheme()
	if p := findInThemes(iconName); p != "" {
		return cacheIcon(iconName, p)
	}
	if p := findInPixmaps(iconName); p != "" {
		return cacheIcon(iconName, p)
	}
	return cacheIcon(iconName, "")
}

func findInThemes(iconName string) string {
	for _, theme := range iconThemes {
		for _, slot := range iconSlots {
			p := filepath.Join(slot[3], theme, slot[0], slot[1], iconName+"."+slot[2])
			if exists(p) {
				return p
			}
		}
	}
	return ""
}

func findInPixmaps(iconName string) string {
	for _, slot := range pixSlots {
		p := filepath.Join(slot[1], iconName+"."+slot[0])
		if exists(p) {
			return p
		}
	}
	return ""
}

func cacheIcon(iconName, path string) string {
	iconCache[iconName] = path
	iconCacheDirty = true
	return path
}
