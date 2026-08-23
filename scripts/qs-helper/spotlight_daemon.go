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

// ── Daemon JSON-lines ────────────────────────────────────────────────────
// spotRequest es un request JSON-lines leído de stdin.
type spotRequest struct {
	ID    string `json:"id"`
	Query string `json:"query"`
}

// spotResponse es una respuesta JSON-lines escrita en stdout. Toda respuesta
// replica el id del request para que el cliente descarte respuestas stale
// (p.ej. una búsqueda lenta que terminó después de enviar un request nuevo).
type spotResponse struct {
	ID    string          `json:"id"`
	Items []spotlightItem `json:"items"`
}

// spotErrorReply es la respuesta para un request que falló al parsear. El
// daemon sigue vivo y solo ese request recibe el error.
type spotErrorReply struct {
	ID    string `json:"id"`
	Error string `json:"error"`
}

// spotlightState cachea lo que el modo one-shot re-lee en cada llamada: la
// lista de apps escaneadas y el mapa de frecency. El daemon lo construye una
// vez y lo reutiliza para todos los requests. Los requests se atienden
// secuencialmente en un solo goroutine (el loop principal), lo que mantiene
// este estado libre de races sin locks.
type spotlightState struct {
	apps    []appInfo
	appsSet bool
	frec    frecencyMap
	frecMod int64
}

// newSpotlightState precarga frecency; las apps se escanean de forma perezosa
// en el primer uso para que `spotlight --daemon` arranque al instante (el cold
// start se traslada al primer request).
func newSpotlightState() *spotlightState {
	s := &spotlightState{frec: loadFrecency()}
	if fi, err := os.Stat(frecencyPath); err == nil {
		s.frecMod = fi.ModTime().Unix()
	}
	return s
}

// appList devuelve la lista de apps cacheada, ejecutando el scan con cache en
// disco una sola vez.
func (s *spotlightState) appList() []appInfo {
	if !s.appsSet {
		s.apps = cachedScanApps()
		s.appsSet = true
	}
	return s.apps
}

// refreshFrecency re-lee el archivo de frecency solo cuando su mtime cambió,
// de modo que un --record desde un proceso separado se tome sin leer el disco
// en cada request.
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

	// Quickshell detiene el Process con SIGTERM; volcamos el cache de íconos
	// antes de salir. El volcado ocurre en el loop principal para no competir
	// nunca con una búsqueda.
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

// handleSpotRequest parsea una línea, ejecuta la búsqueda y escribe la
// respuesta. Una query vacía (o de solo espacios) devuelve la lista completa
// de apps, replicando el modo one-shot `--list-apps` que el modal usaba
// antes para un campo de búsqueda vacío.
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

// writeSpotReply serializa y vuelca una respuesta JSON-lines. Los errores de
// marshal son inalcanzables en la práctica (todos los campos serializan bien),
// así que un fallo solo se loguea a stderr sin matar el daemon.
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
