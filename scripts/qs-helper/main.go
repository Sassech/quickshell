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
	code := dispatchCommand(os.Args[1], os.Args[2:])
	os.Exit(code)
}

func dispatchCommand(cmd string, args []string) int {
	switch cmd {
	case "spotlight":
		return runSpotlight(args)
	case "clipboard":
		return handleClipboardCmd(args)
	case "clipboard-copy":
		return handleClipboardCopyCmd(args)
	case "folder":
		return handleFolderCmd(args)
	case "wallpaper":
		return handleWallpaperCmd(args)
	case "wallpaper-multi":
		return handleWallpaperMultiCmd(args)
	case "wallpaper-save":
		return handleWallpaperSaveCmd(args)
	case "weather":
		return runWeather(args)
	case "weather-search":
		return runWeatherSearch(args)
	case "prefs-weather-set":
		return runPrefsWeatherSet(args)
	case "image-search":
		return runImageSearch(args)
	case "image-download":
		return runImageDownload(args)
	case "updates-check":
		return runUpdatesCheck()
	default:
		fmt.Fprintf(os.Stderr, "qs-helper: subcomando desconocido %q\n", cmd)
		usage()
		return 1
	}
}

func firstArg(args []string) string {
	if len(args) > 0 {
		return args[0]
	}
	return ""
}

func handleClipboardCmd(args []string) int {
	if len(args) > 0 && args[0] == "--daemon" {
		return runClipboardDaemon()
	}
	return runClipboard()
}

func handleClipboardCopyCmd(args []string) int {
	return runClipboardCopy(firstArg(args))
}

func handleFolderCmd(args []string) int {
	return runFolder(firstArg(args))
}

func handleWallpaperCmd(args []string) int {
	return runWallpaper(firstArg(args))
}

func handleWallpaperMultiCmd(args []string) int {
	if len(args) > 0 && args[0] == "--daemon" {
		return runWallpaperMultiDaemon()
	}
	return runWallpaperMulti(args)
}

func handleWallpaperSaveCmd(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: qs-helper wallpaper-save <folder>")
		return 1
	}
	return runWallpaperSave(args[0])
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
