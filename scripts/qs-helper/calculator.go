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
	return evalRPN(tokens)
}

func tokenizeCalc(expr string) ([]calcToken, error) {
	tokens := []calcToken{}
	for i := 0; i < len(expr); {
		c := expr[i]
		switch {
		case c == ' ' || c == '\t':
			i++
		case c >= '0' && c <= '9' || c == '.':
			j := i
			for j < len(expr) && (expr[j] >= '0' && expr[j] <= '9' || expr[j] == '.') {
				j++
			}
			v, err := strconv.ParseFloat(expr[i:j], 64)
			if err != nil {
				return nil, err
			}
			tokens = append(tokens, calcToken{kind: "num", value: v})
			i = j
		case c == '+' || c == '-':
			// Unario si es el primer token o el previo es un operador/lparen
			prev := byte(0)
			if len(tokens) > 0 {
				if tokens[len(tokens)-1].kind == "num" {
					prev = 'n'
				} else if tokens[len(tokens)-1].kind == "rparen" {
					prev = 'n'
				}
			}
			isUnary := len(tokens) == 0 || (prev == 0 && tokens[len(tokens)-1].kind != "rparen" && tokens[len(tokens)-1].kind != "num")
			if isUnary {
				op := "neg"
				if c == '+' {
					op = "pos"
				}
				tokens = append(tokens, calcToken{kind: "op", op: op})
			} else {
				tokens = append(tokens, calcToken{kind: "op", op: string(c)})
			}
			i++
		case c == '*' || c == '/' || c == '%':
			op := string(c)
			// Detectar ** y //
			if c == '*' && i+1 < len(expr) && expr[i+1] == '*' {
				op = "**"
				i++
			}
			if c == '/' && i+1 < len(expr) && expr[i+1] == '/' {
				op = "//"
				i++
			}
			tokens = append(tokens, calcToken{kind: "op", op: op})
			i++
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
	return op == "**"
}

// evalRPN evalúa la expresión con shunting-yard.
func evalRPN(tokens []calcToken) (float64, error) {
	output := []calcToken{}
	ops := []calcToken{}

	for _, t := range tokens {
		switch t.kind {
		case "num":
			output = append(output, t)
		case "op":
			for len(ops) > 0 {
				top := ops[len(ops)-1]
				if top.kind == "lparen" {
					break
				}
				topPrec := opPrecedence(top.op)
				curPrec := opPrecedence(t.op)
				if topPrec > curPrec || (topPrec == curPrec && !opRightAssoc(t.op)) {
					output = append(output, top)
					ops = ops[:len(ops)-1]
				} else {
					break
				}
			}
			ops = append(ops, t)
		case "lparen":
			ops = append(ops, t)
		case "rparen":
			for len(ops) > 0 && ops[len(ops)-1].kind != "lparen" {
				output = append(output, ops[len(ops)-1])
				ops = ops[:len(ops)-1]
			}
			if len(ops) == 0 {
				return 0, strconv.ErrSyntax // paréntesis desbalanceado
			}
			ops = ops[:len(ops)-1] // pop lparen
		}
	}
	for len(ops) > 0 {
		if ops[len(ops)-1].kind == "lparen" {
			return 0, strconv.ErrSyntax
		}
		output = append(output, ops[len(ops)-1])
		ops = ops[:len(ops)-1]
	}

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
		case "+":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			stack = stack[:len(stack)-2]
			stack = append(stack, a+b)
		case "-":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			stack = stack[:len(stack)-2]
			stack = append(stack, a-b)
		case "*":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			stack = stack[:len(stack)-2]
			stack = append(stack, a*b)
		case "/":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			if b == 0 {
				return 0, strconv.ErrSyntax // div por cero
			}
			stack = stack[:len(stack)-2]
			stack = append(stack, a/b)
		case "//":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			if b == 0 {
				return 0, strconv.ErrSyntax
			}
			stack = stack[:len(stack)-2]
			// floor division de Python
			stack = append(stack, math.Floor(a/b))
		case "%":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			if b == 0 {
				return 0, strconv.ErrSyntax
			}
			stack = stack[:len(stack)-2]
			// Floored modulo de Python: a % b = a - b*floor(a/b).
			// (math.Mod de Go trunca y rompe el signo: -7 % 3 = -1, Python da 2)
			stack = append(stack, a-b*math.Floor(a/b))
		case "**":
			if len(stack) < 2 {
				return 0, strconv.ErrSyntax
			}
			b, a := stack[len(stack)-1], stack[len(stack)-2]
			stack = stack[:len(stack)-2]
			stack = append(stack, math.Pow(a, b))
		}
	}
	if len(stack) != 1 {
		return 0, strconv.ErrSyntax
	}
	return stack[0], nil
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
