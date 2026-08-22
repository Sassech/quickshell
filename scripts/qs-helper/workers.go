package main

import (
	"runtime"
	"sync"
)

// parallelRun runs fn(i) for each index in [0, n) using a bounded worker pool
// (min(4, NumCPU) goroutines). Safe for concurrent use on independent indices.
func parallelRun(n int, fn func(i int)) {
	if n == 0 {
		return
	}
	maxWorkers := runtime.NumCPU()
	if maxWorkers > 4 {
		maxWorkers = 4
	}
	if maxWorkers < 1 {
		maxWorkers = 1
	}
	sem := make(chan struct{}, maxWorkers)
	var wg sync.WaitGroup
	for i := range n {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int) {
			defer wg.Done()
			defer func() { <-sem }()
			fn(i)
		}(i)
	}
	wg.Wait()
}
