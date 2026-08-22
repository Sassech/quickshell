package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	cmd := os.Args[1]
	args := os.Args[2:]

	code := 0
	switch cmd {
	case "spotlight":
		code = runSpotlight(args)
	case "clipboard":
		if len(args) > 0 && args[0] == "--daemon" {
			code = runClipboardDaemon()
			break
		}
		code = runClipboard()
	case "clipboard-copy":
		id := ""
		if len(args) > 0 {
			id = args[0]
		}
		code = runClipboardCopy(id)
	case "folder":
		path := ""
		if len(args) > 0 {
			path = args[0]
		}
		code = runFolder(path)
	case "wallpaper":
		folder := ""
		if len(args) > 0 {
			folder = args[0]
		}
		code = runWallpaper(folder)
	case "wallpaper-multi":
		if len(args) > 0 && args[0] == "--daemon" {
			code = runWallpaperMultiDaemon()
			break
		}
		code = runWallpaperMulti(args)
	case "wallpaper-save":
		if len(args) == 0 {
			fmt.Fprintln(os.Stderr, "Usage: qs-helper wallpaper-save <folder>")
			code = 1
			break
		}
		code = runWallpaperSave(args[0])
	case "weather":
		code = runWeather(args)
	case "weather-search":
		code = runWeatherSearch(args)
	case "prefs-weather-set":
		code = runPrefsWeatherSet(args)
	case "image-search":
		code = runImageSearch(args)
	case "image-download":
		code = runImageDownload(args)
	case "updates-check":
		code = runUpdatesCheck()
	default:
		fmt.Fprintf(os.Stderr, "qs-helper: subcomando desconocido %q\n", cmd)
		usage()
		code = 1
	}
	os.Exit(code)
}

func usage() {
	fmt.Fprintln(os.Stderr, `qs-helper — utilidades para la shell quickshell

Uso:
  qs-helper spotlight [--daemon | --list-apps | --record <exec> | <query>]
  qs-helper clipboard [--daemon]
  qs-helper clipboard-copy <id>
  qs-helper folder <path>
  qs-helper wallpaper <folder>
  qs-helper wallpaper-multi [--daemon] <folder1> [folder2] ...
  qs-helper wallpaper-save <folder>
  qs-helper weather [<lat> <lon>]
  qs-helper weather-search "<query>"
  qs-helper prefs-weather-set <lat> <lon> <ciudad> <pais> <auto>
  qs-helper image-search "<query>" [first]
  qs-helper image-download <id> <url> [<folder>]
  qs-helper updates-check`)
}

// ── Helpers compartidos ───────────────────────────────────────────────────

// contextTimeout crea un contexto con timeout (evita repetir imports).
func contextTimeout(d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), d)
}

// expandTilde expande "~" y "~/..." al home del usuario.
func expandTilde(p string) string {
	if p == "" {
		return p
	}
	if p == "~" {
		return homeDir
	}
	if strings.HasPrefix(p, "~/") {
		return filepath.Join(homeDir, p[2:])
	}
	return p
}

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}

// writeJSONLine serializa v como una línea JSON y la escribe en el buffer.
// Los daemons JSON-lines la usan para responder por stdout; un error de
// marshal solo se loguea a stderr sin matar el daemon.
func writeJSONLine(out *bufio.Writer, v any) {
	data, err := json.Marshal(v)
	if err != nil {
		fmt.Fprintf(os.Stderr, "qs-helper: marshalling reply: %v\n", err)
		return
	}
	out.Write(data)
	out.WriteByte('\n')
	out.Flush()
}
