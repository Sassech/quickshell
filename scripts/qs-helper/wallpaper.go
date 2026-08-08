package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const thumbDir = "/tmp/qs-wallpaper-thumbs"

var wallpaperExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".webp": true,
	".bmp": true, ".tiff": true, ".tif": true, ".gif": true,
}

var videoExts = map[string]bool{
	".mp4": true, ".webm": true, ".mkv": true, ".mov": true,
}

func hasMpvpaper() bool {
	_, err := exec.LookPath("mpvpaper")
	return err == nil
}

type wallpaperItem struct {
	Path  string `json:"path"`
	Thumb string `json:"thumb"`
	Name  string `json:"name"`
	Type  string `json:"type"`
}

func makeWallpaperThumb(path string) string {
	safe := strings.ReplaceAll(path, "/", "_")
	safe = strings.ReplaceAll(safe, " ", "_")
	thumb := filepath.Join(thumbDir, safe+".jpg")
	if _, err := os.Stat(thumb); err == nil {
		return thumb
	}
	ext := strings.ToLower(filepath.Ext(path))
	isVideo := videoExts[ext]
	if isVideo {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "ffmpeg", "-y", "-ss", "00:00:00.5", "-i", path,
			"-frames:v", "1", "-q:v", "3",
			"-vf", "scale=180:120:force_original_aspect_ratio=increase,crop=180:120",
			thumb)
		_ = cmd.Run()
	} else {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "magick", path+"[0]",
			"-thumbnail", "180x120^",
			"-gravity", "center",
			"-extent", "180x120",
			thumb)
		_ = cmd.Run()
	}
	if _, err := os.Stat(thumb); err == nil {
		return thumb
	}
	return ""
}

// runWallpaper implementa el subcomando wallpaper (port de wallpaper-list.py).
func runWallpaper(folder string) int {
	expanded := expandTilde(folder)
	if expanded == "" {
		expanded = filepath.Join(homeDir, "Imágenes")
	}
	_ = os.MkdirAll(thumbDir, 0o755)

	mpv := hasMpvpaper()
	var images []string
	if items, err := os.ReadDir(expanded); err == nil {
		// sorted por name.lower()
		sort.Slice(items, func(i, j int) bool {
			return strings.ToLower(items[i].Name()) < strings.ToLower(items[j].Name())
		})
		for _, e := range items {
			if e.IsDir() {
				continue
			}
			ext := strings.ToLower(filepath.Ext(e.Name()))
			if wallpaperExts[ext] || (videoExts[ext] && mpv) {
				images = append(images, filepath.Join(expanded, e.Name()))
			}
		}
	}

	out := []wallpaperItem{}
	for _, p := range images {
		if len(out) >= 60 {
			break
		}
		ext := strings.ToLower(filepath.Ext(p))
		itemType := "image"
		if videoExts[ext] {
			itemType = "video"
		}
		out = append(out, wallpaperItem{
			Path:  p,
			Thumb: makeWallpaperThumb(p),
			Name:  filepath.Base(p),
			Type:  itemType,
		})
	}
	data, _ := json.Marshal(out)
	fmt.Println(string(data))
	return 0
}

// runWallpaperSave implementa wallpaper-save (port de wallpaper-save-config.py).
// Replica el Python: un argumento vacío ("") escribe {"folder": ""} sin error;
// el caso "sin argumento" se valida en main.go.
func runWallpaperSave(folder string) int {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(homeDir, ".config")
	}
	configPath := filepath.Join(configHome, "quickshell", "config", "wallpaper-config.json")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
		return 1
	}
	data, _ := json.Marshal(map[string]string{"folder": folder})
	tmp := configPath + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
		return 1
	}
	if err := os.Rename(tmp, configPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
		return 1
	}
	return 0
}
