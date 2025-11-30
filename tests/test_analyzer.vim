" test_analyzer.vim - Unit tests for frequency analyzer
" Run with: vim -u NONE -S test_analyzer.vim

" Setup test environment
set nocompatible
let s:test_count = 0
let s:test_passed = 0
let s:test_failed = 0

" Add parent directories to runtimepath
let s:script_dir = expand('<sfile>:p:h')
let s:plugin_dir = fnamemodify(s:script_dir, ':h')
execute 'set runtimepath+=' . s:plugin_dir

" Load the analyzer module
runtime autoload/wordpred/analyzer.vim

" Test helper functions
function! s:Assert(condition, message) abort
  let s:test_count += 1
  if a:condition
    let s:test_passed += 1
    echo 'PASS: ' . a:message
  else
    let s:test_failed += 1
    echo 'FAIL: ' . a:message
  endif
endfunction

function! s:AssertEqual(expected, actual, message) abort
  call s:Assert(a:expected ==# a:actual, a:message . ' (expected: ' . string(a:expected) . ', got: ' . string(a:actual) . ')')
endfunction

function! s:AssertGreater(actual, threshold, message) abort
  call s:Assert(a:actual > a:threshold, a:message . ' (expected > ' . a:threshold . ', got: ' . a:actual . ')')
endfunction

" Create a test buffer with content
function! s:CreateTestBuffer(lines) abort
  enew
  call setline(1, a:lines)
  return bufnr('%')
endfunction

" Test 1: Extract words with minimum length
function! s:TestWordExtraction() abort
  echo "\n=== Test: Word Extraction ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'The quick brown fox jumps over the lazy dog.',
        \ 'Hello world! Testing word prediction.',
        \ 'ab cd xyz test'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  let stats = wordpred#analyzer#GetStats(bufnr)
  
  " Should extract words with 3+ characters only (ab, cd excluded)
  call s:AssertGreater(stats.unique_words, 0, 'Should have extracted some words')
  
  " Check specific word
  let freq = wordpred#analyzer#GetWordFrequency('the', bufnr)
  call s:AssertEqual(2, freq, 'Word "the" should appear twice (case-insensitive)')
  
  " Check that short words are not included
  let freq = wordpred#analyzer#GetWordFrequency('ab', bufnr)
  call s:AssertEqual(0, freq, 'Word "ab" should not be counted (too short)')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 2: Case-insensitive counting
function! s:TestCaseInsensitive() abort
  echo "\n=== Test: Case-Insensitive Counting ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'Hello hello HELLO',
        \ 'World WORLD world'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  let freq_hello = wordpred#analyzer#GetWordFrequency('hello', bufnr)
  call s:AssertEqual(3, freq_hello, 'Should count "Hello", "hello", "HELLO" as same word')
  
  let freq_world = wordpred#analyzer#GetWordFrequency('WORLD', bufnr)
  call s:AssertEqual(3, freq_world, 'Should count "World", "WORLD", "world" as same word')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 3: Bigram frequency counting
function! s:TestBigramCounting() abort
  echo "\n=== Test: Bigram Frequency ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'hello world hello universe',
        \ 'hello world again'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  let freq = wordpred#analyzer#GetBigramFrequency('hello', 'world', bufnr)
  call s:AssertEqual(2, freq, 'Bigram "hello world" should appear twice')
  
  let freq = wordpred#analyzer#GetBigramFrequency('hello', 'universe', bufnr)
  call s:AssertEqual(1, freq, 'Bigram "hello universe" should appear once')
  
  let freq = wordpred#analyzer#GetBigramFrequency('world', 'test', bufnr)
  call s:AssertEqual(0, freq, 'Bigram "world test" should not exist')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 4: Prefix matching
function! s:TestPrefixMatching() abort
  echo "\n=== Test: Prefix Matching ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'testing tested test tester',
        \ 'hello world wonderful'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  let matches = wordpred#analyzer#GetWordsWithPrefix('test', bufnr)
  call s:AssertEqual(3, len(matches), 'Should find 3 words starting with "test"')
  call s:Assert(has_key(matches, 'testing'), 'Should find "testing"')
  call s:Assert(has_key(matches, 'tested'), 'Should find "tested"')
  call s:Assert(has_key(matches, 'tester'), 'Should find "tester"')
  call s:Assert(!has_key(matches, 'test'), 'Should not include exact match "test"')
  
  let matches = wordpred#analyzer#GetWordsWithPrefix('wo', bufnr)
  call s:AssertEqual(2, len(matches), 'Should find 2 words starting with "wo"')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 5: Bigram prefix matching
function! s:TestBigramPrefixMatching() abort
  echo "\n=== Test: Bigram Prefix Matching ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'hello world hello wonderful hello wisdom',
        \ 'goodbye world'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  let matches = wordpred#analyzer#GetBigramsWithPrefix('hello', 'w', bufnr)
  call s:AssertEqual(3, len(matches), 'Should find 3 words after "hello" starting with "w"')
  call s:Assert(has_key(matches, 'world'), 'Should find "hello world"')
  call s:Assert(has_key(matches, 'wonderful'), 'Should find "hello wonderful"')
  call s:Assert(has_key(matches, 'wisdom'), 'Should find "hello wisdom"')
  
  let matches = wordpred#analyzer#GetBigramsWithPrefix('goodbye', 'w', bufnr)
  call s:AssertEqual(1, len(matches), 'Should find 1 word after "goodbye" starting with "w"')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 6: Update on buffer change
function! s:TestUpdateOnChange() abort
  echo "\n=== Test: Update on Change ==="
  
  let bufnr = s:CreateTestBuffer(['testing'])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  let stats1 = wordpred#analyzer#GetStats(bufnr)
  
  " Add more content
  call setbufline(bufnr, 2, 'another line with more words')
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  let stats2 = wordpred#analyzer#GetStats(bufnr)
  
  call s:AssertGreater(stats2.unique_words, stats1.unique_words, 'Should have more words after adding content')
  call s:AssertGreater(stats2.last_tick, stats1.last_tick, 'Last tick should be updated')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 7: Clear buffer data
function! s:TestClearData() abort
  echo "\n=== Test: Clear Data ==="
  
  let bufnr = s:CreateTestBuffer(['hello world testing'])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  let stats1 = wordpred#analyzer#GetStats(bufnr)
  call s:AssertGreater(stats1.unique_words, 0, 'Should have words before clear')
  
  call wordpred#analyzer#Clear(bufnr)
  let stats2 = wordpred#analyzer#GetStats(bufnr)
  call s:AssertEqual(0, stats2.unique_words, 'Should have no words after clear')
  call s:AssertEqual(0, stats2.unique_bigrams, 'Should have no bigrams after clear')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 8: Empty buffer
function! s:TestEmptyBuffer() abort
  echo "\n=== Test: Empty Buffer ==="
  
  let bufnr = s:CreateTestBuffer([''])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  let stats = wordpred#analyzer#GetStats(bufnr)
  
  call s:AssertEqual(0, stats.unique_words, 'Empty buffer should have no words')
  call s:AssertEqual(0, stats.unique_bigrams, 'Empty buffer should have no bigrams')
  
  execute 'bwipeout!' bufnr
endfunction

" Run all tests
function! s:RunAllTests() abort
  echo "==================================="
  echo "Running Word Prediction Analyzer Tests"
  echo "==================================="
  
  call s:TestWordExtraction()
  call s:TestCaseInsensitive()
  call s:TestBigramCounting()
  call s:TestPrefixMatching()
  call s:TestBigramPrefixMatching()
  call s:TestUpdateOnChange()
  call s:TestClearData()
  call s:TestEmptyBuffer()
  
  echo "\n==================================="
  echo "Test Results"
  echo "==================================="
  echo "Total tests:  " . s:test_count
  echo "Passed:       " . s:test_passed
  echo "Failed:       " . s:test_failed
  echo "==================================="
  
  if s:test_failed == 0
    echo "All tests passed! ✓"
    quit
  else
    echo "Some tests failed! ✗"
    cquit
  endif
endfunction

" Run tests
call s:RunAllTests()
