package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
)

// Daemon JSON-lines: spotRequest stdin.
type spotRequest struct {
	ID    string `json:"id"`
	Query string `json:"query"`
}

// spotResponse stdout replica id (descarta stale).
type spotResponse struct {
	ID    string          `json:"id"`
	Items []spotlightItem `json:"items"`
}

// spotErrorReply: parse fail solo ese request.
type spotErrorReply struct {
	ID    string `json:"id"`
	Error string `json:"error"`
}

// spotlightState: cache apps+frecency; loop single-goroutine sin locks.
type spotlightState struct {
	apps    []appInfo
	appsSet bool
	frec    frecencyMap
	frecMod int64
}

// newSpotlightState: precarga frecency; apps lazy para arranque instantáneo.
func newSpotlightState() *spotlightState {
	s := &spotlightState{frec: loadFrecency()}
	if fi, err := os.Stat(frecencyPath); err == nil {
		s.frecMod = fi.ModTime().Unix()
	}
	return s
}

// appList: cache en disco una vez.
func (s *spotlightState) appList() []appInfo {
	if !s.appsSet {
		s.apps = cachedScanApps()
		s.appsSet = true
	}
	return s.apps
}

// refreshFrecency: relee solo si mtime cambió.
func (s *spotlightState) refreshFrecency() {
	fi, err := os.Stat(frecencyPath)
	if err != nil || fi.ModTime().Unix() == s.frecMod {
		return
	}
	s.frec = loadFrecency()
	s.frecMod = fi.ModTime().Unix()
}

func runSpotlightDaemon() int {
	loadIconCache()

	st := newSpotlightState()
	lines := make(chan string, 1)

	go func() {
		defer close(lines)
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Buffer(make([]byte, 0, 64*1024), 1*1024*1024)
		for scanner.Scan() {
			lines <- scanner.Text()
		}
		if err := scanner.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "spotlight --daemon: leyendo stdin: %v\n", err)
		}
	}()

	// Quickshell detiene el Process con SIGTERM; volcamos el cache de íconos antes de salir. El volcado ocurre
	// en el loop principal para no competir nunca con una búsqueda.
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)

	out := bufio.NewWriter(os.Stdout)
	for {
		select {
		case line, ok := <-lines:
			if !ok {
				saveIconCache()
				return 0
			}
			handleSpotRequest(line, st, out)
		case <-signals:
			saveIconCache()
			return 0
		}
	}
}

// handleSpotRequest: query vacía → listApps; si no search.
func handleSpotRequest(line string, st *spotlightState, out *bufio.Writer) {
	if strings.TrimSpace(line) == "" {
		return
	}
	var req spotRequest
	if err := json.Unmarshal([]byte(line), &req); err != nil {
		writeSpotReply(out, spotErrorReply{ID: req.ID, Error: err.Error()})
		return
	}
	st.refreshFrecency()
	var items []spotlightItem
	if strings.TrimSpace(req.Query) == "" {
		items = spotlightListApps(st)
	} else {
		items = spotlightSearch(req.Query, st)
	}
	writeSpotReply(out, spotResponse{ID: req.ID, Items: items})
}

// writeSpotReply: marshal JSON-lines; error solo log.
func writeSpotReply(out *bufio.Writer, v any) {
	data, err := json.Marshal(v)
	if err != nil {
		fmt.Fprintf(os.Stderr, "spotlight --daemon: marshalling reply: %v\n", err)
		return
	}
	out.Write(data)
	out.WriteByte('\n')
	out.Flush()
}
