package main

import (
	"strings"
	"unicode"
)

// Separadores de palabra: el patrón corto es para nombres, el largo para
// campos extra (keywords/genericname, que pueden tener ; y ,).
const (
	wordSepNamePattern  = "\\s-_()/"
	wordSepExtraPattern = "\\s-_()/;,"
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
	return fuzzyScoreImpl(query, name, extra, true)
}

// fuzzyScoreNoTypo es fuzzyScore pero sin el nivel de typos (wordCharScore).
// Para búsqueda de archivos en $HOME el typo-tolerance es demasiado
// ruidoso (cualquier nombre largo con las letras sueltas matchea).
func fuzzyScoreNoTypo(query, name, extra string) int {
	return fuzzyScoreImpl(query, name, extra, false)
}

// fuzzyScoreImpl computa el score; withTypo habilita wordCharScore.
func fuzzyScoreImpl(query, name, extra string, withTypo bool) int {
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
	nameWords := splitWords(t, wordSepNamePattern)
	if anyWordPrefix(nameWords, q) {
		return 70
	}
	// Búsqueda multi-token (ej: "virt qemu", "brave btrave")
	if s := tokenScore(q, t, k, nameWords); s > 0 {
		return s
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
	if k != "" && anyWordPrefix(splitWords(k, wordSepExtraPattern), q) {
		return 40
	}
	// Subsecuencia fuzzy SOLO en el nombre (requiere >=3 consecutivos)
	if s := subsequenceScore(q, t, 3); s > 0 {
		return s
	}
	// Tolerancia a typos: solapamiento de chars por palabra (btrave -> brave)
	if withTypo {
		if s := wordCharScore(q, t); s > 0 {
			return s
		}
	}
	return 0
}

func anyWordPrefix(words []string, q string) bool {
	for _, w := range words {
		if w != "" && strings.HasPrefix(w, q) {
			return true
		}
	}
	return false
}

// tokenScore evalúa el nivel multi-token: 65 si todos los tokens matchean
// palabras del nombre, 50 si matchean contra los campos extra.
func tokenScore(q, t, k string, nameWords []string) int {
	tokens := strings.Fields(q)
	if len(tokens) <= 1 {
		return 0
	}
	kwWords := []string{}
	if k != "" {
		kwWords = splitWords(k, wordSepExtraPattern)
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
	for _, word := range splitWords(t, wordSepNamePattern) {
		if len([]rune(word)) < minWordLen {
			continue
		}
		common := commonRunes(sq, sortedRunes(word))
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

// commonRunes cuenta los chars compartidos entre dos secuencias ordenadas
// (merge-style, como el Counter intersection del Python).
func commonRunes(a, b []rune) int {
	common := 0
	i, j := 0, 0
	for i < len(a) && j < len(b) {
		if a[i] == b[j] {
			common++
			i++
			j++
		} else if a[i] < b[j] {
			i++
		} else {
			j++
		}
	}
	return common
}

// splitWords divide s con la expresión regular dada y descarta strings vacíos,
// equivalente al re.split de Python (que los elimina).
func splitWords(s, pattern string) []string {
	sep := func(r rune) bool {
		switch pattern {
		case wordSepNamePattern:
			return unicode.IsSpace(r) || r == '-' || r == '_' || r == '(' || r == ')' || r == '/'
		case wordSepExtraPattern:
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
