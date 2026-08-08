package main

import (
	"math"
	"regexp"
	"strconv"
	"strings"
)

// calcRe replica el gate del Python: solo dígitos, espacios y operadores.
var calcRe = regexp.MustCompile(`^[\d\s+\-*/().^%,]+$`)

type calcToken struct {
	kind  string // "num", "op", "lparen", "rparen"
	value float64
	op    string // "+", "-", "*", "/", "//", "%", "**", "neg", "pos"
}

// shuntingYard convierte la expresión infija a RPN y la evalúa.
// Precedencia Python: ** (derecha-asoc) > unario > * / // % > + -
func evalCalc(expr string) (float64, error) {
	// Normalización igual que Python: ^ -> **, , -> .
	expr = strings.ReplaceAll(expr, "^", "**")
	expr = strings.ReplaceAll(expr, ",", ".")

	tokens, err := tokenizeCalc(expr)
	if err != nil {
		return 0, err
	}
	rpn, err := toRPN(tokens)
	if err != nil {
		return 0, err
	}
	return evalRPN(rpn)
}

func tokenizeCalc(expr string) ([]calcToken, error) {
	tokens := []calcToken{}
	for i := 0; i < len(expr); {
		c := expr[i]
		switch {
		case isSpace(c):
			i++
		case isNumberStart(c):
			v, next, err := scanNumber(expr, i)
			if err != nil {
				return nil, err
			}
			tokens = append(tokens, calcToken{kind: "num", value: v})
			i = next
		case isSign(c):
			tokens = append(tokens, calcToken{kind: "op", op: classifySign(tokens, c)})
			i++
		case isOpStart(c):
			op, next := scanOp(expr, i)
			tokens = append(tokens, calcToken{kind: "op", op: op})
			i = next
		case c == '(':
			tokens = append(tokens, calcToken{kind: "lparen"})
			i++
		case c == ')':
			tokens = append(tokens, calcToken{kind: "rparen"})
			i++
		default:
			return nil, strconv.ErrSyntax
		}
	}
	return tokens, nil
}

func isSpace(c byte) bool {
	return c == ' ' || c == '\t'
}

func isNumberStart(c byte) bool {
	return c >= '0' && c <= '9' || c == '.'
}

func isSign(c byte) bool {
	return c == '+' || c == '-'
}

func isOpStart(c byte) bool {
	return c == '*' || c == '/' || c == '%'
}

// classifySign clasifica +/− como binario o unario según el contexto:
// unario si es el primer token o el previo es operador/lparen.
func classifySign(tokens []calcToken, c byte) string {
	if len(tokens) > 0 {
		last := tokens[len(tokens)-1].kind
		if last == "num" || last == "rparen" {
			return string(c)
		}
	}
	if c == '+' {
		return "pos"
	}
	return "neg"
}

func scanNumber(expr string, i int) (float64, int, error) {
	j := i
	for j < len(expr) && isNumberStart(expr[j]) {
		j++
	}
	v, err := strconv.ParseFloat(expr[i:j], 64)
	if err != nil {
		return 0, i, err
	}
	return v, j, nil
}

func scanOp(expr string, i int) (string, int) {
	c := expr[i]
	if c == '*' && i+1 < len(expr) && expr[i+1] == '*' {
		return "**", i + 2
	}
	if c == '/' && i+1 < len(expr) && expr[i+1] == '/' {
		return "//", i + 2
	}
	return string(c), i + 1
}

func opPrecedence(op string) int {
	switch op {
	case "**":
		return 4
	case "neg", "pos":
		return 3
	case "*", "/", "//", "%":
		return 2
	case "+", "-":
		return 1
	}
	return 0
}

func opRightAssoc(op string) bool {
	return op == "**" || op == "neg" || op == "pos"
}

func toRPN(tokens []calcToken) ([]calcToken, error) {
	output := []calcToken{}
	ops := []calcToken{}
	for _, t := range tokens {
		var err error
		switch t.kind {
		case "num":
			output = append(output, t)
		case "op":
			output, ops = pushOperator(t, output, ops)
		case "lparen":
			ops = append(ops, t)
		case "rparen":
			output, ops, err = popUntilLParen(output, ops)
		}
		if err != nil {
			return nil, err
		}
	}
	return flushOps(output, ops)
}

// pushOperator apila un operador, drenando antes los de mayor precedencia.
func pushOperator(t calcToken, output, ops []calcToken) ([]calcToken, []calcToken) {
	for len(ops) > 0 {
		top := ops[len(ops)-1]
		if top.kind == "lparen" {
			break
		}
		if !shouldPop(top.op, t.op) {
			break
		}
		output = append(output, top)
		ops = ops[:len(ops)-1]
	}
	return output, append(ops, t)
}

func flushOps(output, ops []calcToken) ([]calcToken, error) {
	for len(ops) > 0 {
		if ops[len(ops)-1].kind == "lparen" {
			return nil, strconv.ErrSyntax
		}
		output = append(output, ops[len(ops)-1])
		ops = ops[:len(ops)-1]
	}
	return output, nil
}

// shouldPop indica si el operador en el tope debe salir antes que cur.
func shouldPop(top, cur string) bool {
	// Python: 2**-2 = 2 ** (-2). Un unario a la derecha de ** es parte del
	// exponente y NO saca el **; a la izquierda (-2**2 = -(2**2)) sí lo saca.
	if (cur == "neg" || cur == "pos") && top == "**" {
		return false
	}
	topPrec := opPrecedence(top)
	curPrec := opPrecedence(cur)
	if topPrec > curPrec {
		return true
	}
	return topPrec == curPrec && !opRightAssoc(cur)
}

func popUntilLParen(output, ops []calcToken) ([]calcToken, []calcToken, error) {
	for len(ops) > 0 {
		top := ops[len(ops)-1]
		if top.kind == "lparen" {
			return output, ops[:len(ops)-1], nil
		}
		output = append(output, top)
		ops = ops[:len(ops)-1]
	}
	return output, ops, strconv.ErrSyntax // paréntesis desbalanceado
}

func evalRPN(output []calcToken) (float64, error) {
	stack := []float64{}
	for _, t := range output {
		if t.kind == "num" {
			stack = append(stack, t.value)
			continue
		}
		if len(stack) == 0 {
			return 0, strconv.ErrSyntax
		}
		switch t.op {
		case "neg":
			stack[len(stack)-1] = -stack[len(stack)-1]
		case "pos":
			// no-op
		default:
			a, b, rest, ok := popBinary(stack)
			if !ok {
				return 0, strconv.ErrSyntax
			}
			res, err := applyBinary(t.op, a, b)
			if err != nil {
				return 0, err
			}
			stack = append(rest, res)
		}
	}
	if len(stack) != 1 {
		return 0, strconv.ErrSyntax
	}
	return stack[0], nil
}

// popBinary saca los dos topes de la pila como (a, b), con a el operando izquierdo.
func popBinary(stack []float64) (a, b float64, rest []float64, ok bool) {
	if len(stack) < 2 {
		return 0, 0, stack, false
	}
	b, a = stack[len(stack)-1], stack[len(stack)-2]
	return a, b, stack[:len(stack)-2], true
}

// applyBinary aplica un operador binario con semántica Python
// (floor division y floored modulo).
func applyBinary(op string, a, b float64) (float64, error) {
	switch op {
	case "+":
		return a + b, nil
	case "-":
		return a - b, nil
	case "*":
		return a * b, nil
	case "/":
		if b == 0 {
			return 0, strconv.ErrSyntax
		}
		return a / b, nil
	case "//":
		if b == 0 {
			return 0, strconv.ErrSyntax
		}
		return math.Floor(a / b), nil
	case "%":
		if b == 0 {
			return 0, strconv.ErrSyntax
		}
		// Floored modulo de Python: a % b = a - b*floor(a/b).
		// (math.Mod de Go trunca y rompe el signo: -7 % 3 = -1, Python da 2)
		return a - b*math.Floor(a/b), nil
	case "**":
		return math.Pow(a, b), nil
	}
	return 0, strconv.ErrSyntax
}

// formatCalcResult normaliza como Python: 4.0 -> 4, y formatea floats.
func formatCalcResult(val float64) string {
	if val == math.Trunc(val) && !math.IsInf(val, 0) && math.Abs(val) < 1e15 {
		return strconv.FormatInt(int64(val), 10)
	}
	return strconv.FormatFloat(val, 'g', -1, 64)
}

// tryCalc evalúa el query si es una expresión de calculadora válida.
// Retorna (val, ok). ok=false si no es calc o falla la eval.
func tryCalc(query string) (string, bool) {
	if !calcRe.MatchString(query) || query == "" {
		return "", false
	}
	hasDigit := false
	for _, r := range query {
		if r >= '0' && r <= '9' {
			hasDigit = true
			break
		}
	}
	if !hasDigit {
		return "", false
	}
	val, err := evalCalc(query)
	if err != nil {
		return "", false
	}
	return formatCalcResult(val), true
}
