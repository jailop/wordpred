#!/bin/bash
# benchmark.sh - Performance benchmark for word prediction plugin

echo "=========================================="
echo "Word Prediction Plugin Benchmark"
echo "=========================================="
echo ""

# Check if Vim/Neovim are available
if ! command -v vim &> /dev/null; then
    echo "Error: vim not found"
    exit 1
fi

# Create temporary benchmark file
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# Generate test content
cat > $TMPFILE << 'EOF'
" Benchmark script for word prediction
set nocompatible

" Load plugin
let s:plugin_dir = expand('<sfile>:p:h:h')
execute 'set runtimepath+=' . s:plugin_dir
runtime plugin/wordpred.vim

" Enable performance monitoring
let g:wordpred_perf_monitor = 1
let g:wordpred_enabled = 1

" Create test buffer
enew
call setline(1, [
      \ 'The quick brown fox jumps over the lazy dog.',
      \ 'The fox was very quick and clever.',
      \ 'Testing word prediction with frequency analysis.',
      \ 'This is a test document for testing purposes.',
      \ 'Word prediction uses statistical language models.',
      \ 'The quick fox jumped again and again.',
      \ 'Machine learning and natural language processing.',
      \ 'Natural language understanding requires context.',
      \ 'Artificial intelligence and machine learning.',
      \ 'Deep learning and neural networks.',
      \ 'Data science and statistical analysis.',
      \ 'Natural language processing techniques.',
      \ 'Computational linguistics and text analysis.',
      \ 'Information retrieval and search engines.'
      \ ])

" Run benchmark
echo "Running benchmark..."
echo ""

" Benchmark 1: Initial frequency update
let start = reltime()
call wordpred#analyzer#UpdateFrequencies()
let elapsed = str2float(reltimestr(reltime(start))) * 1000
echo "Initial frequency update: " . printf("%.2f", elapsed) . " ms"

" Benchmark 2: Repeated updates
let total = 0
let iterations = 10
for i in range(iterations)
  call setline(line('$') + 1, 'Additional line ' . i)
  let start = reltime()
  call wordpred#analyzer#UpdateFrequencies()
  let elapsed = str2float(reltimestr(reltime(start))) * 1000
  let total += elapsed
endfor
echo "Average update time (" . iterations . " iterations): " . printf("%.2f", total / iterations) . " ms"

" Benchmark 3: Predictions
let total = 0
let iterations = 100
for i in range(iterations)
  let start = reltime()
  let pred = wordpred#predict#PredictWord('test')
  let elapsed = str2float(reltimestr(reltime(start))) * 1000
  let total += elapsed
endfor
echo "Average prediction time (" . iterations . " iterations): " . printf("%.2f", total / iterations) . " ms"

" Benchmark 4: Bigram predictions
let total = 0
let iterations = 100
for i in range(iterations)
  let start = reltime()
  let pred = wordpred#predict#PredictWord('nat', bufnr('%'), 'natural')
  let elapsed = str2float(reltimestr(reltime(start))) * 1000
  let total += elapsed
endfor
echo "Average bigram prediction (" . iterations . " iterations): " . printf("%.2f", total / iterations) . " ms"

" Show overall statistics
echo ""
echo "=== Plugin Performance Statistics ==="
echo wordpred#performance#FormatStats()

" Show model statistics
echo ""
echo "=== Model Statistics ==="
let stats = wordpred#analyzer#GetStats()
echo "Unique words: " . stats.unique_words
echo "Unique bigrams: " . stats.unique_bigrams

quit
EOF

# Run benchmark
echo "Running Vim benchmark..."
vim -u NONE -S "$TMPFILE" 2>&1 | grep -v "^$"

echo ""
echo "=========================================="
echo "Benchmark Complete"
echo "=========================================="
