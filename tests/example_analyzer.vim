" example_analyzer.vim - Interactive example of the frequency analyzer
" Usage: vim -S example_analyzer.vim

" Setup
set nocompatible
let s:script_dir = expand('<sfile>:p:h')
let s:plugin_dir = fnamemodify(s:script_dir, ':h')
execute 'set runtimepath+=' . s:plugin_dir

" Load the analyzer
runtime autoload/wordpred/analyzer.vim

" Create a sample buffer with content
echo "Creating sample buffer with text..."
enew
call setline(1, [
      \ 'The quick brown fox jumps over the lazy dog.',
      \ 'The fox was very quick and very clever.',
      \ 'Testing word prediction with frequency analysis.',
      \ 'This is a test document for testing purposes.',
      \ 'Word prediction uses statistical language models.',
      \ 'The quick fox jumped again and again.'
      \ ])

echo "Sample text loaded. Analyzing..."
echo ""

" Update frequencies
call wordpred#analyzer#UpdateFrequencies()

" Show statistics
echo "=== Frequency Model Statistics ==="
let stats = wordpred#analyzer#GetStats()
echo "Unique words: " . stats.unique_words
echo "Unique bigrams: " . stats.unique_bigrams
echo ""

" Test some word frequencies
echo "=== Word Frequencies ==="
echo "Frequency of 'the': " . wordpred#analyzer#GetWordFrequency('the')
echo "Frequency of 'quick': " . wordpred#analyzer#GetWordFrequency('quick')
echo "Frequency of 'fox': " . wordpred#analyzer#GetWordFrequency('fox')
echo "Frequency of 'test': " . wordpred#analyzer#GetWordFrequency('test')
echo ""

" Test bigram frequencies
echo "=== Bigram Frequencies ==="
echo "Frequency of 'quick fox': " . wordpred#analyzer#GetBigramFrequency('quick', 'fox')
echo "Frequency of 'word prediction': " . wordpred#analyzer#GetBigramFrequency('word', 'prediction')
echo "Frequency of 'the quick': " . wordpred#analyzer#GetBigramFrequency('the', 'quick')
echo ""

" Test prefix matching
echo "=== Prefix Matching ==="
echo "Words starting with 'test':"
let test_matches = wordpred#analyzer#GetWordsWithPrefix('test')
for [word, freq] in items(test_matches)
  echo "  " . word . " (frequency: " . freq . ")"
endfor
echo ""

echo "Words starting with 'qu':"
let qu_matches = wordpred#analyzer#GetWordsWithPrefix('qu')
for [word, freq] in items(qu_matches)
  echo "  " . word . " (frequency: " . freq . ")"
endfor
echo ""

" Test bigram prefix matching
echo "=== Bigram Prefix Matching ==="
echo "Words that follow 'the' and start with 'qu':"
let the_qu_matches = wordpred#analyzer#GetBigramsWithPrefix('the', 'qu')
for [word, freq] in items(the_qu_matches)
  echo "  " . word . " (frequency: " . freq . ")"
endfor
echo ""

echo "Words that follow 'word' and start with 'pre':"
let word_pre_matches = wordpred#analyzer#GetBigramsWithPrefix('word', 'pre')
for [word, freq] in items(word_pre_matches)
  echo "  " . word . " (frequency: " . freq . ")"
endfor
echo ""

echo "=== Interactive Mode ==="
echo "The buffer is still open. You can:"
echo "  - Edit the text"
echo "  - Call :call wordpred#analyzer#UpdateFrequencies()"
echo "  - Query frequencies with :echo wordpred#analyzer#GetWordFrequency('word')"
echo "  - Type :q to quit"
echo ""
