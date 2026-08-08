package main

import (
	"strings"
	"unicode"
)

// fuzzy_score replica fuzzy_score(query, name, extra) de spotlight-search.py.
// Retorna 0-100. 0 = sin coincidencia.
// Jerarquía exacta (el orden importa):
//
//	100 = prefijo exacto del nombre
//	 70 = alguna palabra del nombre comienza con el query
//	 65 = multi-token: todos los tokens del query matchean palabras del nombre
//	 55 = el query es substring del nombre
//	 50 = multi-token matchea con campos extra (keywords/genericname)
//	 45 = el query es substring de los campos extra
//	 40 = alguna palabra de los campos extra comienza con el query
//	1-30 = match por subsecuencia en el nombre (requiere >=3 consecutivos)
//	5-20 = tolerancia a typos por solapamiento de chars por palabra
func fuzzyScore(query, name, extra string) int {
	q := strings.ToLower(strings.TrimSpace(query))
	t := strings.ToLower(name)
	k := strings.ToLower(extra)

	if q == "" {
		return 0
	}

	// Prefijo exacto completo
	if strings.HasPrefix(t, q) {
		return 100
	}

	// Cualquier palabra del nombre empieza con el query completo
	nameWords := splitWords(t, "\\s-_()/")
	for _, w := range nameWords {
		if w != "" && strings.HasPrefix(w, q) {
			return 70
		}
	}

	// Búsqueda multi-token (ej: "virt qemu", "brave btrave")
	tokens := strings.Fields(q)
	if len(tokens) > 1 {
		kwWords := []string{}
		if k != "" {
			kwWords = splitWords(k, "\\s-_()/;,")
		}
		allWords := append(append([]string{}, nameWords...), kwWords...)

		tokenMatch := func(tok string, words []string, fullText string) bool {
			for _, w := range words {
				if w != "" && strings.HasPrefix(w, tok) {
					return true
				}
			}
			return strings.Contains(fullText, tok)
		}

		if allOK(tokens, nameWords, t, tokenMatch) {
			return 65
		}
		if k != "" && allOK(tokens, allWords, t+" "+k, tokenMatch) {
			return 50
		}
	}

	// Substring directo en el nombre
	if strings.Contains(t, q) {
		return 55
	}

	// Substring en campos extra
	if k != "" && strings.Contains(k, q) {
		return 45
	}

	// Alguna palabra de los campos extra comienza con el query
	if k != "" {
		for _, w := range splitWords(k, "\\s-_()/;,") {
			if w != "" && strings.HasPrefix(w, q) {
				return 40
			}
		}
	}

	// Subsecuencia fuzzy SOLO en el nombre (requiere >=3 consecutivos)
	if s := subsequenceScore(q, t, 3); s > 0 {
		return s
	}

	// Tolerancia a typos: solapamiento de chars por palabra (btrave -> brave)
	if s := wordCharScore(q, t); s > 0 {
		return s
	}

	return 0
}

// fuzzyScoreNoTypo es fuzzyScore pero sin el nivel 9 (wordCharScore).
// Para búsqueda de archivos sobre todo $HOME el typo-tolerance es demasiado
// ruidoso (cualquier nombre largo con las letras sueltas matchea).
func fuzzyScoreNoTypo(query, name, extra string) int {
	s := fuzzyScore(query, name, extra)
	// Re-evaluamos sin el typo: si fuzzyScore llegó al paso 9, retorna 0.
	// Más simple: reusamos la lógica pero con una versión que corta antes.
	if s <= 30 {
		// El typo devuelve 5-20; la subsecuencia 1-30. No podemos distinguir
		// por valor, así que recalculamos explícitamente sin typo.
		return fuzzyScoreNoTypoImpl(query, name, extra)
	}
	return s
}

func fuzzyScoreNoTypoImpl(query, name, extra string) int {
	q := strings.ToLower(strings.TrimSpace(query))
	t := strings.ToLower(name)
	k := strings.ToLower(extra)

	if q == "" {
		return 0
	}
	if strings.HasPrefix(t, q) {
		return 100
	}
	nameWords := splitWords(t, "\\s-_()/")
	for _, w := range nameWords {
		if w != "" && strings.HasPrefix(w, q) {
			return 70
		}
	}
	tokens := strings.Fields(q)
	if len(tokens) > 1 {
		kwWords := []string{}
		if k != "" {
			kwWords = splitWords(k, "\\s-_()/;,")
		}
		allWords := append(append([]string{}, nameWords...), kwWords...)
		tokenMatch := func(tok string, words []string, fullText string) bool {
			for _, w := range words {
				if w != "" && strings.HasPrefix(w, tok) {
					return true
				}
			}
			return strings.Contains(fullText, tok)
		}
		if allOK(tokens, nameWords, t, tokenMatch) {
			return 65
		}
		if k != "" && allOK(tokens, allWords, t+" "+k, tokenMatch) {
			return 50
		}
	}
	if strings.Contains(t, q) {
		return 55
	}
	if k != "" && strings.Contains(k, q) {
		return 45
	}
	if k != "" {
		for _, w := range splitWords(k, "\\s-_()/;,") {
			if w != "" && strings.HasPrefix(w, q) {
				return 40
			}
		}
	}
	if s := subsequenceScore(q, t, 3); s > 0 {
		return s
	}
	return 0
}

func allOK(tokens []string, words []string, fullText string, f func(string, []string, string) bool) bool {
	for _, tok := range tokens {
		if !f(tok, words, fullText) {
			return false
		}
	}
	return true
}

// subsequenceScore replica _subsequence_score: 1-30 si todos los chars de q
// aparecen en orden en t y max_consecutive >= min_consecutive.
func subsequenceScore(q, t string, minConsecutive int) int {
	qr := []rune(q)
	tr := []rune(t)
	qi := 0
	consecutive := 0
	maxConsecutive := 0
	for _, ch := range tr {
		if qi < len(qr) && ch == qr[qi] {
			qi++
			consecutive++
			if consecutive > maxConsecutive {
				maxConsecutive = consecutive
			}
		} else {
			consecutive = 0
		}
	}
	if qi < len(qr) || maxConsecutive < minConsecutive {
		return 0
	}
	ratio := float64(maxConsecutive) / float64(len(qr))
	score := int(ratio * 30)
	if score < 1 {
		return 1
	}
	return score
}

// wordCharScore replica _word_char_score: tolerancia a typos comparando chars
// del query contra cada palabra del texto. >=80% -> score proporcional.
func wordCharScore(q, t string) int {
	sq := sortedRunes(q)
	best := 0
	minWordLen := 2
	if len([]rune(q))-2 > minWordLen {
		minWordLen = len([]rune(q)) - 2
	}
	for _, word := range splitWords(t, "\\s-_()/") {
		if len([]rune(word)) < minWordLen {
			continue
		}
		sw := sortedRunes(word)
		common := 0
		i, j := 0, 0
		for i < len(sq) && j < len(sw) {
			if sq[i] == sw[j] {
				common++
				i++
				j++
			} else if sq[i] < sw[j] {
				i++
			} else {
				j++
			}
		}
		if len([]rune(q)) == 0 {
			continue
		}
		simQ := float64(common) / float64(len([]rune(q)))
		if simQ >= 0.80 {
			s := int(simQ * 20)
			if s < 5 {
				s = 5
			}
			if s > best {
				best = s
			}
		}
	}
	return best
}

// splitWords divide s con la expresión regular dada y descarta strings vacíos,
// equivalente al re.split de Python (que los elimina).
func splitWords(s, pattern string) []string {
	sep := func(r rune) bool {
		switch pattern {
		case "\\s-_()/":
			return unicode.IsSpace(r) || r == '-' || r == '_' || r == '(' || r == ')' || r == '/'
		case "\\s-_()/;,":
			return unicode.IsSpace(r) || r == '-' || r == '_' || r == '(' || r == ')' || r == '/' || r == ';' || r == ','
		default:
			return unicode.IsSpace(r)
		}
	}
	fields := strings.FieldsFunc(s, sep)
	// FieldsFunc ya descarta strings vacíos automáticamente
	return fields
}

func sortedRunes(s string) []rune {
	r := []rune(s)
	for i := 1; i < len(r); i++ {
		for j := i; j > 0 && r[j] < r[j-1]; j-- {
			r[j], r[j-1] = r[j-1], r[j]
		}
	}
	return r
}
