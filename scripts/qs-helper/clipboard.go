package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const clipboardLogFile = "/tmp/qs-clipboard.log"

func clipboardLog(msg string) {
	f, err := os.OpenFile(clipboardLogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\n", time.Now().Format("2006-01-02 15:04:05"), msg)
}

func hasMagick() bool {
	_, err := exec.LookPath("magick")
	return err == nil
}

type clipEntry struct {
	ID       string `json:"id"`
	Preview  string `json:"preview"`
	IsBinary bool   `json:"isBinary"`
	Thumb    string `json:"thumb"`
}

// generateThumbnail replica generate_thumbnail del Python.
func generateThumbnail(entryID, preview string) string {
	thumbPath := filepath.Join("/tmp", "qs-clip-"+entryID+".png")
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	rawPath := filepath.Join("/tmp", "qs-raw-"+entryID)
	line := []byte(entryID + "\t" + preview)

	ctx, cancel := contextTimeout(10 * time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "cliphist", "decode")
	cmd.Stdin = bytes.NewReader(line)
	out, err := cmd.Output()
	if err != nil || len(out) < 50 {
		return ""
	}
	if err := os.WriteFile(rawPath, out, 0o600); err != nil {
		return ""
	}
	defer os.Remove(rawPath)

	mctx, mcancel := contextTimeout(10 * time.Second)
	defer mcancel()
	mcmd := exec.CommandContext(mctx, "magick", rawPath,
		"-thumbnail", "72x72^", "-gravity", "center", "-extent", "72x72", thumbPath)
	_ = mcmd.Run()

	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	return ""
}

// runClipboard implementa el subcomando clipboard.
func runClipboard() int {
	if !hasMagick() {
		// Igual lista, sin thumbs de binarios.
		entries := clipboardList()
		out, _ := json.Marshal(entries)
		fmt.Println(string(out))
		return 0
	}
	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	result, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[list] cliphist error: " + err.Error())
		fmt.Println("[]")
		return 0
	}

	entries := []clipEntry{}
	thumbTasks := []struct {
		idx     int
		id      string
		preview string
	}{}

	scanner := bufio.NewScanner(bytes.NewReader(result))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 {
			continue
		}
		entryID := line[:idx]
		preview := line[idx+1:]
		isBinary := strings.HasPrefix(preview, "[[ binary")
		entries = append(entries, clipEntry{
			ID:       entryID,
			Preview:  preview,
			IsBinary: isBinary,
			Thumb:    "",
		})
		if isBinary && strings.Contains(strings.ToLower(preview), "png") {
			thumbTasks = append(thumbTasks, struct {
				idx     int
				id      string
				preview string
			}{len(entries) - 1, entryID, preview})
		}
	}

	// Thumbnails en paralelo, 4 workers.
	if len(thumbTasks) > 0 {
		var wg sync.WaitGroup
		sem := make(chan struct{}, 4)
		for _, t := range thumbTasks {
			wg.Add(1)
			go func(t struct {
				idx     int
				id      string
				preview string
			}) {
				defer wg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()
				thumb := generateThumbnail(t.id, t.preview)
				entries[t.idx].Thumb = thumb
			}(t)
		}
		wg.Wait()
	}

	out, _ := json.Marshal(entries)
	fmt.Println(string(out))
	return 0
}

// clipboardList sin magick: solo lista.
func clipboardList() []clipEntry {
	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	result, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[list] cliphist error: " + err.Error())
		return []clipEntry{}
	}
	entries := []clipEntry{}
	scanner := bufio.NewScanner(bytes.NewReader(result))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 {
			continue
		}
		entries = append(entries, clipEntry{
			ID:       line[:idx],
			Preview:  line[idx+1:],
			IsBinary: strings.HasPrefix(line[idx+1:], "[[ binary"),
			Thumb:    "",
		})
	}
	return entries
}

// binaryMIME infiere el MIME de una preview binaria, replicando clipboard-copy.sh.
func binaryMIME(preview string) string {
	p := strings.ToLower(preview)
	switch {
	case strings.Contains(p, "png"):
		return "image/png"
	case strings.Contains(p, "jpg") || strings.Contains(p, "jpeg"):
		return "image/jpeg"
	case strings.Contains(p, "gif"):
		return "image/gif"
	case strings.Contains(p, "webp"):
		return "image/webp"
	case strings.Contains(p, "svg"):
		return "image/svg+xml"
	default:
		return "application/octet-stream"
	}
}

// runClipboardCopy implementa el subcomando clipboard-copy <id>.
// Exit codes replican clipboard-copy.sh: 1 ID vacío, 2 cliphist list falló,
// 3 ID no encontrado, 4 decode/fallo de copia.
func runClipboardCopy(id string) int {
	if id == "" {
		clipboardLog("[copy] Error: ID vacío")
		return 1
	}

	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	list, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[copy] Error: cliphist list falló: " + err.Error())
		return 2
	}

	entry := ""
	preview := ""
	scanner := bufio.NewScanner(bytes.NewReader(list))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 || line[:idx] != id {
			continue
		}
		entry = line
		preview = line[idx+1:]
		break
	}
	if entry == "" {
		clipboardLog("[copy] Error: ID '" + id + "' no encontrado en cliphist")
		return 3
	}

	dctx, dcancel := contextTimeout(10 * time.Second)
	defer dcancel()
	decCmd := exec.CommandContext(dctx, "cliphist", "decode")
	decCmd.Stdin = bytes.NewReader([]byte(entry + "\n"))
	decoded, err := decCmd.Output()
	if err != nil {
		clipboardLog("[copy] Error: cliphist decode falló: " + err.Error())
		return 4
	}

	// lanzarWlCopy ejecuta wl-copy sin esperar su salida. wl-copy forkea al
	// background para mantener viva la selección y el hijo hereda el pipe de
	// stdout: esperar con Output()/CombinedOutput() cuelga hasta el EOF del
	// pipe. Solo Start() + liberar el handle replica el comportamiento bash.
	lanzarWlCopy := func(mime string, payload []byte) bool {
		cmd := exec.Command("wl-copy")
		if mime != "" {
			cmd = exec.Command("wl-copy", "--type", mime)
		}
		cmd.Stdin = bytes.NewReader(payload)
		cmd.Stdout = nil
		cmd.Stderr = nil
		if err := cmd.Start(); err != nil {
			clipboardLog("[copy] Error: wl-copy Start falló (" + mime + "): " + err.Error())
			return false
		}
		cmd.Process.Release()
		return true
	}

	if strings.HasPrefix(preview, "[[ binary") {
		mime := binaryMIME(preview)
		if !lanzarWlCopy(mime, decoded) {
			return 4
		}
		clipboardLog("[copy] OK: " + id + " (" + mime + ")")
		return 0
	}

	// Rama no-binaria: detecta MIME real; si es imagen usa --type, si no texto plano.
	mimeType := http.DetectContentType(decoded)
	if strings.HasPrefix(mimeType, "image/") {
		if !lanzarWlCopy(mimeType, decoded) {
			return 4
		}
		clipboardLog("[copy] OK: " + id + " (" + mimeType + " - auto-detected)")
		return 0
	}

	if !lanzarWlCopy("", decoded) {
		return 4
	}
	clipboardLog("[copy] OK: " + id + " (text)")
	return 0
}
