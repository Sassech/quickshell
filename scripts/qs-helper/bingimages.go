package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"html"
)

// ── Buscador de imágenes (Bing Image Search, por scraping) ────────────────
// Sin API key ni keyring: se scrapea el HTML de resultados. La `murl` (media
// URL) ES la imagen original → se descarga SIEMPRE murl. La etiqueta de
// resolución se calcula con las dimensiones del resultado (mw/mh):
//   ≥3840×2160 → "4K";  ≥1920×1080 → "1080p";  sino → "SD".
// No se inventan variantes UHD ni se consulta ningún endpoint de la API.

// browserUA es un User-Agent real de navegador: sin uno Bing bloquea.
const browserUA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

const bingSearchURL = "https://www.bing.com/images/search?q=%s&count=35&form=HDRSC2"
const bingAsyncURL = "https://www.bing.com/images/async?q=%s&first=%d&count=35&mmasync=1"

// ── Parseo del HTML ────────────────────────────────────────────────────────
// Los resultados están en <a class="iusc" ... m="{...}">: el atributo `m` es
// JSON con las comillas escapadas a entidades HTML (&quot;) que contiene
// murl/turl/mw/mh. Doble pasada + fallback suelto (el scraping es frágil).

var iuscMRe = regexp.MustCompile(`(?s)<a[^>]*\bclass="iusc"[^>]*\bm="([^"]*)"`)
var anyMRe = regexp.MustCompile(`\bm="(\{[^"]*)"`)
var murlRe = regexp.MustCompile(`"murl"\s*:\s*"([^"]*)"`)
var turlRe = regexp.MustCompile(`"turl"\s*:\s*"([^"]*)"`)
var mwRe = regexp.MustCompile(`"mw"\s*:\s*"?(\d+)`)
var mhRe = regexp.MustCompile(`"mh"\s*:\s*"?(\d+)`)

type bingHit struct {
	Murl    string
	Turl    string
	Mwidth  int
	Mheight int
}

type bingItem struct {
	ID     string `json:"id"`
	Thumb  string `json:"thumb"`
	URL    string `json:"url"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Res    string `json:"res"`
}

type bingPath struct {
	Path string `json:"path"`
}

// group1 devuelve el primer grupo capturado del regex ("" si no matchea).
func group1(re *regexp.Regexp, s string) string {
	if m := re.FindStringSubmatch(s); len(m) == 2 {
		return m[1]
	}
	return ""
}

func atoiSafe(s string) int {
	n, _ := strconv.Atoi(s)
	return n
}

// bingHitFromM interpreta el valor del atributo m (ya con entidades HTML
// decodificadas): primero JSON, y si mw/mh vienen como string (o el JSON
// falla), extracción manual con regex.
func bingHitFromM(m string) (bingHit, bool) {
	var raw struct {
		Murl    string `json:"murl"`
		Turl    string `json:"turl"`
		Mwidth  int    `json:"mw"`
		Mheight int    `json:"mh"`
	}
	if err := json.Unmarshal([]byte(m), &raw); err != nil || raw.Murl == "" {
		raw.Murl = group1(murlRe, m)
		raw.Turl = group1(turlRe, m)
		raw.Mwidth = atoiSafe(group1(mwRe, m))
		raw.Mheight = atoiSafe(group1(mhRe, m))
	}
	if raw.Murl == "" {
		return bingHit{}, false
	}
	return bingHit{Murl: raw.Murl, Turl: raw.Turl, Mwidth: raw.Mwidth, Mheight: raw.Mheight}, true
}

// parseBingResults extrae hits de una página de Bing. Pasadas: (1) anchors
// <a class="iusc"> con su m; (2) cualquier atributo m del documento; (3) el
// murl más suelto. Dedupe por murl.
func parseBingResults(page []byte) []bingHit {
	// Una sola conversión + unescaping al inicio; todos los regexp operan sobre pageStr.
	pageStr := html.UnescapeString(string(page))

	var hits []bingHit
	seen := map[string]bool{}
	add := func(h bingHit) {
		if h.Murl == "" || seen[h.Murl] {
			return
		}
		seen[h.Murl] = true
		hits = append(hits, h)
	}

	for _, m := range iuscMRe.FindAllStringSubmatch(pageStr, -1) {
		if h, ok := bingHitFromM(m[1]); ok {
			add(h)
		}
	}

	if len(hits) == 0 {
		for _, m := range anyMRe.FindAllStringSubmatch(pageStr, -1) {
			if h, ok := bingHitFromM(m[1]); ok {
				add(h)
			}
		}
	}

	if len(hits) == 0 {
		for _, m := range murlRe.FindAllStringSubmatch(pageStr, -1) {
			add(bingHit{Murl: m[1]})
		}
	}
	return hits
}

// ── Búsqueda (image-search) ────────────────────────────────────────────────

// fetchBingHits consulta una página de resultados. first es el índice 1-based
// del primer resultado a pedir (1 = primera página). La primera página usa la
// página de búsqueda HTML con fallback al endpoint async (doble pasada); las
// siguientes van directo al async (la página HTML solo devuelve la primera
// tanda de 35).
func fetchBingHits(query string, first int) []bingHit {
	q := url.QueryEscape(query)
	if first > 1 {
		data, err := httpGetWithUA(fmt.Sprintf(bingAsyncURL, q, first), 8<<20)
		if err != nil {
			logTo("bingsearch", fmt.Sprintf("página %d: %s", first, err.Error()))
			return nil
		}
		return parseBingResults(data)
	}
	data, err := httpGetWithUA(fmt.Sprintf(bingSearchURL, q), 8<<20)
	if err != nil {
		logTo("bingsearch", "primera pasada: "+err.Error())
	} else if hits := parseBingResults(data); len(hits) > 0 {
		return hits
	}
	data, err = httpGetWithUA(fmt.Sprintf(bingAsyncURL, q, 1), 8<<20)
	if err != nil {
		logTo("bingsearch", "segunda pasada: "+err.Error())
		return nil
	}
	return parseBingResults(data)
}

// bingRes etiqueta la resolución con las dimensiones de la media: la regla
// cerrada es "4K sino 1080p", con SD para lo que no llega a Full HD.
func bingRes(w, h int) string {
	if w >= 3840 && h >= 2160 {
		return "4K"
	}
	if w >= 1920 && h >= 1080 {
		return "1080p"
	}
	return "SD"
}

// bingItemID es un hash corto de la murl: estable entre llamadas (para que
// image-download con el mismo resultado sea idempotente).
func bingItemID(murl string) string {
	h := sha1.Sum([]byte(murl))
	return hex.EncodeToString(h[:5])
}

// bingPrefix completa una URL relativa de Bing con el host.
func bingPrefix(u string) string {
	if strings.HasPrefix(u, "http") {
		return u
	}
	return "https://www.bing.com" + u
}

// runImageSearch implementa `image-search "<query>" [--first=N]`.
// first es el índice 1-based del primer resultado a pedir (por defecto 1) y
// sirve para paginar. Se usa flag explícito (no posición) porque las queries
// pueden terminar en números ("windows 11") y la heurística posicional los
// comería.
func runImageSearch(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Uso: qs-helper image-search <query> [--first=N]")
		return 1
	}
	first := 1
	queryParts := []string{}
	for _, a := range args {
		if strings.HasPrefix(a, "--first=") {
			if f, err := strconv.Atoi(strings.TrimPrefix(a, "--first=")); err == nil && f >= 1 {
				first = f
			}
			continue
		}
		queryParts = append(queryParts, a)
	}
	query := strings.Join(queryParts, " ")
	hits := fetchBingHits(query, first)
	if len(hits) == 0 {
		fmt.Fprintln(os.Stderr, "image-search: Bing no devolvió resultados parseables (¿bloqueo o sin red?)")
		logTo("bingsearch", fmt.Sprintf("búsqueda %q: sin resultados en ninguna pasada", query))
		return 1
	}

	items := []bingItem{}
	for _, h := range hits {
		if h.Turl == "" {
			continue
		}
		items = append(items, bingItem{
			ID:     bingItemID(h.Murl),
			Thumb:  bingPrefix(h.Turl),
			URL:    bingPrefix(h.Murl),
			Width:  h.Mwidth,
			Height: h.Mheight,
			Res:    bingRes(h.Mwidth, h.Mheight),
		})
	}
	out, _ := json.Marshal(items)
	fmt.Println(string(out))
	logTo("bingsearch", fmt.Sprintf("búsqueda %q: %d resultados", query, len(items)))
	return 0
}

// ── Descarga (image-download) ──────────────────────────────────────────────

var wParamRe = regexp.MustCompile(`[?&](?:w|width)=(\d{2,5})`)
var hParamRe = regexp.MustCompile(`[?&](?:h|height)=(\d{2,5})`)
var pathSizeRe = regexp.MustCompile(`[_-](\d{3,5})x(\d{3,5})[.\/]`)

// bingSizeFromURL intenta derivar ancho/alto de la URL (query params w/h o
// width/height; fallback a un patrón de tamaño en el path). 0 si no se puede.
func bingSizeFromURL(u string) (int, int) {
	w, h := 0, 0
	if m := wParamRe.FindStringSubmatch(u); len(m) == 2 {
		w, _ = strconv.Atoi(m[1])
	}
	if m := hParamRe.FindStringSubmatch(u); len(m) == 2 {
		h, _ = strconv.Atoi(m[1])
	}
	if w > 0 && h > 0 {
		return w, h
	}
	if m := pathSizeRe.FindStringSubmatch(u); len(m) == 3 {
		w, _ = strconv.Atoi(m[1])
		h, _ = strconv.Atoi(m[2])
	}
	return w, h
}

// urlPathExtrae la extensión del path de la URL ("" si no hay).
func urlPathExt(u string) string {
	p, err := url.Parse(u)
	if err != nil {
		return ""
	}
	return strings.ToLower(filepath.Ext(p.Path))
}

// runImageDownload implementa `image-download <id> <url> [<folder>]`.
// Guarda bing-<id>-<W>x<H>.jpg cuando W/H se derivan de la URL; si no,
// bing-<id>-<timestamp>.jpg. Idempotente si el archivo ya existe.
func runImageDownload(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "Uso: qs-helper image-download <id> <url> [<folder>]")
		return 1
	}
	id := args[0]
	urlStr := bingPrefix(args[1])
	folder := ""
	if len(args) >= 3 {
		folder = args[2]
	}
	if folder == "" {
		// Carpeta dedicada para descargas de Bing: usa XDG_PICTURES_DIR si
		// está definida, sino ~/Pictures — sin caracteres no-ASCII hardcodeados.
		picDir := os.Getenv("XDG_PICTURES_DIR")
		if picDir == "" {
			picDir = filepath.Join(homeDir, "Pictures")
		}
		folder = filepath.Join(picDir, "Bing")
	}
	folder = expandTilde(folder)

	ext := urlPathExt(urlStr)
	if ext == "" || len(ext) > 5 {
		ext = ".jpg"
	}
	var name string
	if w, h := bingSizeFromURL(urlStr); w > 0 && h > 0 {
		name = fmt.Sprintf("bing-%s-%dx%d%s", id, w, h, ext)
	} else {
		name = fmt.Sprintf("bing-%s-%d%s", id, time.Now().Unix(), ext)
	}
	target := filepath.Join(folder, name)
	if _, err := os.Stat(target); err == nil {
		out, _ := json.Marshal(bingPath{Path: target})
		fmt.Println(string(out))
		return 0
	}

	data, err := httpGetBytes(urlStr, 64<<20)
	if err != nil {
		fmt.Fprintf(os.Stderr, "image-download: %v\n", err)
		logTo("bingsearch", "descarga: "+err.Error())
		return 1
	}
	if err := os.MkdirAll(folder, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "image-download: %v\n", err)
		return 1
	}
	if err := os.WriteFile(target, data, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "image-download: %v\n", err)
		return 1
	}

	out, _ := json.Marshal(bingPath{Path: target})
	fmt.Println(string(out))
	logTo("bingsearch", "descargado "+target)
	return 0
}
