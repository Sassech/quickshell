package main

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// HTTP compartido

// userAgent helper
const userAgent = "qs-helper/1.0 (quickshell)"

// httpClient con timeout
var httpClient = &http.Client{Timeout: 15 * time.Second}

// httpGetBytes: GET UA genérico; maxBytes limita gigas.
func httpGetBytes(url string, maxBytes int64) ([]byte, error) {
	return httpGet(context.Background(), url, maxBytes, userAgent)
}

// httpGetWithUA: UA navegador (Bing bloquea genérico).
func httpGetWithUA(url string, maxBytes int64) ([]byte, error) {
	return httpGet(context.Background(), url, maxBytes, browserUA)
}

// httpGet: UA configurable + límite.
func httpGet(ctx context.Context, url string, maxBytes int64, ua string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", ua)
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	if maxBytes > 0 {
		return io.ReadAll(io.LimitReader(resp.Body, maxBytes))
	}
	return io.ReadAll(resp.Body)
}

// Cache disco

// cacheDir ~/.cache/qs-helper
var cacheDir = func() string {
	if d, err := os.UserCacheDir(); err == nil && d != "" {
		return filepath.Join(d, "qs-helper")
	}
	return filepath.Join(homeDir, ".cache", "qs-helper")
}()

// cacheKey: id→filename seguro (URLs cortadas+hash).
func cacheKey(id string) string {
	var b strings.Builder
	for _, r := range id {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9',
			r == '-', r == '.', r == '_':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}
	s := b.String()
	if len(s) > 80 {
		h := sha1.Sum([]byte(id))
		s = s[:40] + "-" + hex.EncodeToString(h[:6])
	}
	return s
}

// cacheRead: datos si ttl ok (≤0 acepta vencido).
func cacheRead(key string, ttl time.Duration) ([]byte, bool) {
	p := filepath.Join(cacheDir, cacheKey(key)+".json")
	fi, err := os.Stat(p)
	if err != nil {
		return nil, false
	}
	if ttl > 0 && time.Since(fi.ModTime()) > ttl {
		return nil, false
	}
	data, err := os.ReadFile(p)
	if err != nil {
		return nil, false
	}
	if !json.Valid(data) {
		_ = os.Remove(p) // invalidar cache corrupto
		return nil, false
	}
	return data, true
}

// cacheWrite: tmp+Rename atómico.
func cacheWrite(key string, data []byte) {
	_ = os.MkdirAll(cacheDir, 0o755)
	p := filepath.Join(cacheDir, cacheKey(key)+".json")
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, p)
}

// cacheGet: cache si aplica→fresh()→stale fallback.
func cacheGet(key string, ttl time.Duration, fresh func() ([]byte, error)) (data []byte, stale bool, err error) {
	if data, ok := cacheRead(key, ttl); ok {
		return data, false, nil
	}
	data, err = fresh()
	if err != nil {
		if stale, ok := cacheRead(key, 0); ok {
			return stale, true, nil
		}
		return nil, false, err
	}
	cacheWrite(key, data)
	return data, false, nil
}

// logTo: /tmp/qs-<name>.log.
func logTo(name, msg string) {
	f, err := os.OpenFile(filepath.Join(os.TempDir(), "qs-"+name+".log"),
		os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\n", time.Now().Format("2006-01-02 15:04:05"), msg)
}
