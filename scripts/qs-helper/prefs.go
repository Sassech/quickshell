package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
)

// Preferencias de la shell (config/preferences.json)

type wallpaperPref struct {
	Folder string `json:"folder"`
}

type weatherPref struct {
	Lat         float64 `json:"lat"`
	Lon         float64 `json:"lon"`
	Auto        bool    `json:"auto"`
	CityName    string  `json:"cityName"`
	CountryName string  `json:"countryName"`
}

type prefs struct {
	Wallpaper wallpaperPref `json:"wallpaper"`
	Weather   weatherPref   `json:"weather"`
}

// configDir resuelve el directorio de configuración de la shell.
func configDir() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return filepath.Join(d, "quickshell", "config")
	}
	return filepath.Join(homeDir, ".config", "quickshell", "config")
}

// prefsPath es la ruta completa a preferences.json.
func prefsPath() string {
	return filepath.Join(configDir(), "preferences.json")
}

// loadPrefs lee preferences.json; si falta o está inválido usa defaults.
func loadPrefs() prefs {
	p := prefs{}
	if data, err := os.ReadFile(prefsPath()); err == nil {
		if err := json.Unmarshal(data, &p); err != nil {
			log.Printf("prefs: failed to parse %s: %v (using defaults)", prefsPath(), err)
		}
	}
	if p.Wallpaper.Folder == "" {
		p.Wallpaper.Folder = "~/Pictures"
	}
	if !p.Weather.Auto && p.Weather.Lat == 0 && p.Weather.Lon == 0 {
		p.Weather.Auto = true
	}
	return p
}

// savePrefs escribe preferences.json preservando todos los campos (merge).
func savePrefs(p prefs) error {
	_ = os.MkdirAll(filepath.Dir(prefsPath()), 0o755)
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	tmp := prefsPath() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, prefsPath())
}

// runPrefsWeatherSet implementa el subcomando prefs-weather-set.
// Argumentos: lat lon cityName countryName auto(true|false)
func runPrefsWeatherSet(args []string) int {
	if len(args) < 5 {
		fmt.Fprintln(os.Stderr, "prefs-weather-set: faltan argumentos (lat lon ciudad pais auto)")
		return 1
	}
	p := loadPrefs()
	lat, err := strconv.ParseFloat(args[0], 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "prefs: invalid float %q: %v\n", args[0], err)
		return 1
	}
	lon, err := strconv.ParseFloat(args[1], 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "prefs: invalid float %q: %v\n", args[1], err)
		return 1
	}
	isAuto := args[4] == "true"
	p.Weather = weatherPref{
		Lat:         lat,
		Lon:         lon,
		CityName:    args[2],
		CountryName: args[3],
		Auto:        isAuto,
	}
	if err := savePrefs(p); err != nil {
		fmt.Fprintf(os.Stderr, "prefs-weather-set: %v\n", err)
		return 1
	}
	return 0
}
