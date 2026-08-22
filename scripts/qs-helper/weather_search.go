package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"time"
)

// ── Geocodificación por nombre (Open-Meteo Geocoding API) ─────────────────

const weatherSearchURL = "https://geocoding-api.open-meteo.com/v1/search?name=%s&count=8&language=es&format=json"

// geoResult es un resultado de búsqueda normalizado para el QML.
type geoResult struct {
	Name    string  `json:"name"`
	Region  string  `json:"region,omitempty"`
	Country string  `json:"country,omitempty"`
	Lat     float64 `json:"lat"`
	Lon     float64 `json:"lon"`
}

// omGeoResult modela el shape que devuelve la API de Open-Meteo Geocoding.
type omGeoResult struct {
	ID        int     `json:"id"`
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Country   string  `json:"country"`
	Admin1    string  `json:"admin1"`
	Admin2    string  `json:"admin2"`
}

// runWeatherSearch implementa el subcomando weather-search "<query>".
// Busca ubicaciones por nombre usando Open-Meteo Geocoding (sin API key).
// Salida: JSON array de geoResult. Sin resultados → []. Error de API → exit 1.
func runWeatherSearch(args []string) int {
	if len(args) == 0 || args[0] == "" {
		fmt.Fprintln(os.Stderr, "weather-search: falta el argumento <query>")
		return 1
	}
	query := args[0]

	cKey := "weather-search-" + cacheKey(query)
	apiURL := fmt.Sprintf(weatherSearchURL, url.QueryEscape(query))

	data, _, err := cacheGet(cKey, 1*time.Hour, func() ([]byte, error) {
		return httpGetBytes(apiURL, 1<<20)
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "weather-search: API falló: %v\n", err)
		return 1
	}

	var resp struct {
		Results []omGeoResult `json:"results"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		fmt.Fprintf(os.Stderr, "weather-search: respuesta inválida: %v\n", err)
		return 1
	}

	// Normalizar resultados: elegir region = admin1 > admin2 > "".
	out := make([]geoResult, 0, len(resp.Results))
	for _, r := range resp.Results {
		region := r.Admin1
		if region == "" {
			region = r.Admin2
		}
		out = append(out, geoResult{
			Name:    r.Name,
			Region:  region,
			Country: r.Country,
			Lat:     r.Latitude,
			Lon:     r.Longitude,
		})
	}

	// Sin resultados → array vacío (no es error). make garantiza slice no-nil.
	b, _ := json.Marshal(out)
	fmt.Println(string(b))
	return 0
}
