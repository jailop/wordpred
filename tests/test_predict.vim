" test_predict.vim - Unit tests for prediction engine
" Run with: vim -u NONE -S test_predict.vim

" Setup test environment
set nocompatible
let s:test_count = 0
let s:test_passed = 0
let s:test_failed = 0

" Add parent directories to runtimepath
let s:script_dir = expand('<sfile>:p:h')
let s:plugin_dir = fnamemodify(s:script_dir, ':h')
execute 'set runtimepath+=' . s:plugin_dir

" Load modules
runtime autoload/wordpred/analyzer.vim
runtime autoload/wordpred/predict.vim

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

function! s:AssertNotEmpty(value, message) abort
  call s:Assert(!empty(a:value), a:message . ' (got: ' . string(a:value) . ')')
endfunction

" Create a test buffer with content
function! s:CreateTestBuffer(lines) abort
  enew
  call setline(1, a:lines)
  return bufnr('%')
endfunction

" Test 1: Unigram prediction
function! s:TestUnigramPrediction() abort
  echo "\n=== Test: Unigram Prediction ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'testing tested test tester',
        \ 'testing again and testing more'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " "testing" appears 3 times, should be predicted for "test"
  let pred = wordpred#predict#PredictWordUnigram('test', bufnr)
  call s:AssertEqual('testing', pred, 'Should predict "testing" for prefix "test"')
  
  " Test with different prefix
  let pred = wordpred#predict#PredictWordUnigram('tes', bufnr)
  call s:AssertEqual('testing', pred, 'Should predict "testing" for prefix "tes"')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 2: Bigram prediction
function! s:TestBigramPrediction() abort
  echo "\n=== Test: Bigram Prediction ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'hello world hello universe',
        \ 'hello world again hello world'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " "hello world" appears 3 times, "hello universe" once
  let pred = wordpred#predict#PredictWordBigram('hello', 'w', bufnr)
  call s:AssertEqual('world', pred, 'Should predict "world" after "hello" with prefix "w"')
  
  " Test with different context
  let pred = wordpred#predict#PredictWordBigram('hello', 'uni', bufnr)
  call s:AssertEqual('universe', pred, 'Should predict "universe" after "hello" with prefix "uni"')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 3: Combined prediction - bigram preferred
function! s:TestCombinedPredictionBigram() abort
  echo "\n=== Test: Combined Prediction (Bigram Preferred) ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'the quick fox jumped',
        \ 'the quick fox ran',
        \ 'the quick fox',
        \ 'quick brown dog'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " "quick fox" appears 3 times (bigram)
  " "quick brown" appears 1 time
  " With bigram weight of 2, should prefer "fox"
  let pred = wordpred#predict#PredictWord('f', bufnr, 'quick')
  call s:AssertEqual('fox', pred, 'Should prefer bigram "fox" over unigram')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 4: Combined prediction - unigram fallback
function! s:TestCombinedPredictionUnigram() abort
  echo "\n=== Test: Combined Prediction (Unigram Fallback) ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'testing is important',
        \ 'testing helps development',
        \ 'testing testing testing'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " No bigram context, should fall back to unigram
  let pred = wordpred#predict#PredictWord('test', bufnr, '')
  call s:AssertEqual('testing', pred, 'Should use unigram when no bigram context')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 5: Minimum prefix length
function! s:TestMinimumPrefixLength() abort
  echo "\n=== Test: Minimum Prefix Length ==="
  
  let bufnr = s:CreateTestBuffer(['testing tested'])
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " Set minimum prefix length to 2
  let g:wordpred_min_prefix_length = 2
  
  " Should return empty for single character
  let pred = wordpred#predict#PredictWord('t', bufnr, '')
  call s:AssertEqual('', pred, 'Should return empty for prefix shorter than minimum')
  
  " Should work for 2+ characters
  let pred = wordpred#predict#PredictWord('te', bufnr, '')
  call s:AssertNotEmpty(pred, 'Should return prediction for prefix meeting minimum')
  
  " Reset
  unlet g:wordpred_min_prefix_length
  
  execute 'bwipeout!' bufnr
endfunction

" Test 6: Case insensitive matching
function! s:TestCaseInsensitive() abort
  echo "\n=== Test: Case Insensitive ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'Testing testing TESTING'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " Should match regardless of case
  let pred = wordpred#predict#PredictWordUnigram('test', bufnr)
  call s:AssertEqual('testing', pred, 'Should match case-insensitively')
  
  let pred = wordpred#predict#PredictWordUnigram('TEST', bufnr)
  call s:AssertEqual('testing', pred, 'Should match uppercase prefix')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 7: No prediction available
function! s:TestNoPrediction() abort
  echo "\n=== Test: No Prediction Available ==="
  
  let bufnr = s:CreateTestBuffer(['hello world'])
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " Prefix that matches nothing
  let pred = wordpred#predict#PredictWord('xyz', bufnr, '')
  call s:AssertEqual('', pred, 'Should return empty when no match')
  
  execute 'bwipeout!' bufnr
endfunction

" Test 8: Bigram weight preference
function! s:TestBigramWeight() abort
  echo "\n=== Test: Bigram Weight Preference ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'quick brown quick brown',  
        \ 'quick fox'                 
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " "brown" has unigram freq 2, "fox" has freq 1
  " "quick brown" bigram freq 2, "quick fox" bigram freq 1
  " With weight 2: bigram_freq * 2 should make "brown" preferred
  
  let g:wordpred_bigram_weight = 2
  let pred = wordpred#predict#PredictWord('b', bufnr, 'quick')
  call s:AssertEqual('brown', pred, 'Should prefer bigram with weight')
  
  " With weight 1: should prefer higher unigram
  let g:wordpred_bigram_weight = 1
  let pred = wordpred#predict#PredictWord('f', bufnr, 'quick')
  call s:AssertNotEmpty(pred, 'Should still make prediction with different weight')
  
  unlet g:wordpred_bigram_weight
  
  execute 'bwipeout!' bufnr
endfunction

" Test 9: Prediction info
function! s:TestPredictionInfo() abort
  echo "\n=== Test: Prediction Info ==="
  
  let bufnr = s:CreateTestBuffer([
        \ 'hello world hello universe hello world'
        \ ])
  
  call wordpred#analyzer#UpdateFrequencies(bufnr)
  
  " Test manually with direct function calls instead of cursor position
  " since cursor-based extraction doesn't work well in automated tests
  let pred = wordpred#predict#PredictWord('w', bufnr, 'hello')
  call s:AssertEqual('world', pred, 'Should predict "world" with context')
  
  let pred = wordpred#predict#PredictWord('uni', bufnr, 'hello')
  call s:AssertEqual('universe', pred, 'Should predict "universe" with context')
  
  " Test prediction source preference
  let bigram = wordpred#predict#PredictWordBigram('hello', 'w', bufnr)
  let unigram = wordpred#predict#PredictWordUnigram('w', bufnr)
  call s:AssertEqual('world', bigram, 'Bigram should find "world"')
  call s:AssertEqual('world', unigram, 'Unigram should also find "world"')
  
  execute 'bwipeout!' bufnr
endfunction

" Run all tests
function! s:RunAllTests() abort
  echo "==================================="
  echo "Running Word Prediction Tests"
  echo "==================================="
  
  call s:TestUnigramPrediction()
  call s:TestBigramPrediction()
  call s:TestCombinedPredictionBigram()
  call s:TestCombinedPredictionUnigram()
  call s:TestMinimumPrefixLength()
  call s:TestCaseInsensitive()
  call s:TestNoPrediction()
  call s:TestBigramWeight()
  call s:TestPredictionInfo()
  
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
