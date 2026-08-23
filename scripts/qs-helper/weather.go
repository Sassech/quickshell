package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"time"
)

// Clima vía Open-Meteo con geo-IP opcional

type weatherGeo struct {
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
	City string  `json:"city"`
}

// weatherOutput mantiene el shape que consume el QML existente: current,
// hourly y daily son EXACTAMENTE las claves de la respuesta open-meteo.
type weatherOutput struct {
	Geo     weatherGeo      `json:"geo"`
	Current json.RawMessage `json:"current"`
	Hourly  json.RawMessage `json:"hourly"`
	Daily   json.RawMessage `json:"daily"`
	Stale   bool            `json:"stale,omitempty"`
}

// weatherURL es la misma consulta que usaba WeatherProvider.qml con curl.
const weatherURL = "https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f" +
	"&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day" +
	"&hourly=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure,relative_humidity_2m,visibility,precipitation_probability,is_day" +
	"&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" +
	"&forecast_days=7&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto"

// geoInfo consulta la geo-localización por IP (cache 24h).
func geoInfo() (weatherGeo, error) {
	var g weatherGeo
	data, _, err := cacheGet("geoip", 24*time.Hour, func() ([]byte, error) {
		return httpGetBytes("http://ip-api.com/json/", 1<<20)
	})
	if err != nil {
		return g, err
	}
	var resp struct {
		Status string  `json:"status"`
		Lat    float64 `json:"lat"`
		Lon    float64 `json:"lon"`
		City   string  `json:"city"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		return g, err
	}
	if resp.Status != "success" {
		return g, fmt.Errorf("ip-api: status %s", resp.Status)
	}
	return weatherGeo{Lat: resp.Lat, Lon: resp.Lon, City: resp.City}, nil
}

// runWeather implementa el subcomando weather [lat] [lon].
// Prioridad de coordenadas: args > preferencias (manual) > geo-IP.
func runWeather(args []string) int {
	var g weatherGeo

	if len(args) >= 2 {
		lat, err1 := strconv.ParseFloat(args[0], 64)
		lon, err2 := strconv.ParseFloat(args[1], 64)
		if err1 != nil || err2 != nil {
			fmt.Fprintln(os.Stderr, "weather: lat/lon inválidos")
			return 1
		}
		g = weatherGeo{Lat: lat, Lon: lon}
	} else {
		p := loadPrefs()
		if !p.Weather.Auto && (p.Weather.Lat != 0 || p.Weather.Lon != 0) {
			g = weatherGeo{Lat: p.Weather.Lat, Lon: p.Weather.Lon, City: p.Weather.CityName}
		} else {
			var err error
			g, err = geoInfo()
			if err != nil {
				fmt.Fprintf(os.Stderr, "weather: geo-IP falló: %v\n", err)
				return 1
			}
		}
	}

	url := fmt.Sprintf(weatherURL, g.Lat, g.Lon)
	key := "weather-" + cacheKey(fmt.Sprintf("%.4f-%.4f", g.Lat, g.Lon))
	data, stale, err := cacheGet(key, 10*time.Minute, func() ([]byte, error) {
		return httpGetBytes(url, 8<<20)
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "weather: %v\n", err)
		return 1
	}

	var om struct {
		Current json.RawMessage `json:"current"`
		Hourly  json.RawMessage `json:"hourly"`
		Daily   json.RawMessage `json:"daily"`
	}
	if err := json.Unmarshal(data, &om); err != nil {
		fmt.Fprintf(os.Stderr, "weather: respuesta inválida: %v\n", err)
		return 1
	}
	out := weatherOutput{Geo: g, Current: om.Current, Hourly: om.Hourly, Daily: om.Daily, Stale: stale}
	b, _ := json.Marshal(out)
	fmt.Println(string(b))
	return 0
}
