" demo.vim - Interactive demonstration of word prediction plugin
" Usage: vim -S demo.vim (or source this file in Vim/Neovim)

" Setup plugin path
let s:script_dir = expand('<sfile>:p:h')
execute 'set runtimepath+=' . s:script_dir

" Load plugin
runtime plugin/wordpred.vim

" Create demo buffer with sample content
enew
call setline(1, [
      \ 'Welcome to the Word Prediction Demo!',
      \ '',
      \ 'Instructions:',
      \ '1. Enter insert mode (press "i")',
      \ '2. Start typing a word that appears in this text',
      \ '3. You will see a gray prediction appear',
      \ '4. Press <Tab> to accept the prediction',
      \ '5. Or keep typing to change the prediction',
      \ '',
      \ 'Sample text for building the frequency model:',
      \ '',
      \ 'The quick brown fox jumps over the lazy dog.',
      \ 'The fox was very quick and clever.',
      \ 'Testing word prediction with frequency analysis.',
      \ 'This is a test document for testing purposes.',
      \ 'Word prediction uses statistical language models.',
      \ 'The quick fox jumped again and again.',
      \ 'Machine learning and natural language processing.',
      \ 'Natural language understanding requires context.',
      \ '',
      \ '--- Try typing below this line ---',
      \ ''
      \ ])

" Update the frequency model
call wordpred#analyzer#UpdateFrequencies()

" Show statistics
echo "\n=== Word Prediction Demo ==="
let stats = wordpred#analyzer#GetStats()
echo "Frequency model loaded:"
echo "  Unique words: " . stats.unique_words
echo "  Unique bigrams: " . stats.unique_bigrams
echo ""
echo "Try typing:"
echo "  - 'qui' (should suggest 'quick')"
echo "  - 'The qui' (context-aware: 'quick' after 'The')"
echo "  - 'test' (should suggest 'testing')"
echo "  - 'word pred' (should suggest 'prediction')"
echo ""
echo "Commands available:"
echo "  :WordPredStats - Show statistics"
echo "  :WordPredInfo - Show current prediction info"
echo "  :WordPredToggle - Enable/disable prediction"
echo ""
echo "Press 'i' to enter insert mode and start typing!"
echo "Press <Tab> to accept predictions."
echo ""

" Move cursor to typing area
call cursor(line('$'), 1)
