" predict.vim - Prediction engine for word completion
" Combines unigram and bigram models to predict word completions

if exists('g:autoloaded_wordpred_predict')
  finish
endif
let g:autoloaded_wordpred_predict = 1

" Get the word under cursor (current prefix being typed)
function! s:GetCurrentWord() abort
  let line = getline('.')
  let col = col('.') - 1
  
  " Find start of word
  let start = col
  while start > 0 && line[start - 1] =~# '[a-zA-Z]'
    let start -= 1
  endwhile
  
  " Extract the word prefix
  if start < col
    return strpart(line, start, col - start)
  endif
  
  return ''
endfunction

" Get the previous word before cursor
function! s:GetPreviousWord() abort
  let line = getline('.')
  let col = col('.') - 1
  
  " Find start of current word
  let pos = col
  while pos > 0 && line[pos - 1] =~# '[a-zA-Z]'
    let pos -= 1
  endwhile
  
  " Skip whitespace before current word
  while pos > 0 && line[pos - 1] =~# '\s'
    let pos -= 1
  endwhile
  
  " Find end of previous word
  let end = pos
  if end == 0
    return ''
  endif
  
  " Find start of previous word
  let start = end
  while start > 0 && line[start - 1] =~# '[a-zA-Z]'
    let start -= 1
  endwhile
  
  if start < end
    return strpart(line, start, end - start)
  endif
  
  return ''
endfunction

" Predict word using unigram model (frequency-based)
function! wordpred#predict#PredictWordUnigram(prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  
  if len(a:prefix) < get(g:, 'wordpred_min_prefix_length', 1)
    return ''
  endif
  
  " Get all words matching prefix
  let matches = wordpred#analyzer#GetWordsWithPrefix(a:prefix, bufnr)
  
  if empty(matches)
    return ''
  endif
  
  " Find word with highest frequency
  let best_word = ''
  let max_freq = 0
  
  for [word, freq] in items(matches)
    if freq > max_freq
      let max_freq = freq
      let best_word = word
    endif
  endfor
  
  return best_word
endfunction

" Predict word using bigram model (context-aware)
function! wordpred#predict#PredictWordBigram(prev_word, prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  
  if empty(a:prev_word) || len(a:prefix) < 1
    return ''
  endif
  
  " Get all bigrams matching the pattern
  let matches = wordpred#analyzer#GetBigramsWithPrefix(a:prev_word, a:prefix, bufnr)
  
  if empty(matches)
    return ''
  endif
  
  " Find word with highest bigram frequency
  let best_word = ''
  let max_freq = 0
  
  for [word, freq] in items(matches)
    if freq > max_freq
      let max_freq = freq
      let best_word = word
    endif
  endfor
  
  return best_word
endfunction

" Combined prediction: bigram + unigram with weighting
function! wordpred#predict#PredictWord(prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let prev_word = a:0 > 1 ? a:2 : ''
  
  if len(a:prefix) < get(g:, 'wordpred_min_prefix_length', 1)
    return ''
  endif
  
  " Try bigram prediction first (context-aware)
  let bigram_pred = ''
  if !empty(prev_word)
    let bigram_pred = wordpred#predict#PredictWordBigram(prev_word, a:prefix, bufnr)
  endif
  
  " Try unigram prediction
  let unigram_pred = wordpred#predict#PredictWordUnigram(a:prefix, bufnr)
  
  " If both predictions exist, choose based on frequency weighting
  if !empty(bigram_pred) && !empty(unigram_pred)
    let bigram_freq = wordpred#analyzer#GetBigramFrequency(prev_word, bigram_pred, bufnr)
    let unigram_freq = wordpred#analyzer#GetWordFrequency(unigram_pred, bufnr)
    let bigram_weight = get(g:, 'wordpred_bigram_weight', 2)
    
    " Prefer bigram if its weighted frequency is higher
    if bigram_freq * bigram_weight >= unigram_freq
      return bigram_pred
    else
      return unigram_pred
    endif
  endif
  
  " Return whichever prediction exists
  if !empty(bigram_pred)
    return bigram_pred
  endif
  
  return unigram_pred
endfunction

" Get prediction for current cursor position
function! wordpred#predict#GetCurrentPrediction() abort
  let prefix = s:GetCurrentWord()
  
  if empty(prefix)
    return ''
  endif
  
  let prev_word = s:GetPreviousWord()
  let prediction = wordpred#predict#PredictWord(prefix, bufnr('%'), prev_word)
  
  " Return only the completion part (remove the prefix)
  if !empty(prediction) && prediction !=? prefix
    return strpart(prediction, len(prefix))
  endif
  
  return ''
endfunction

" Get full prediction info for debugging/display
function! wordpred#predict#GetPredictionInfo() abort
  let prefix = s:GetCurrentWord()
  let prev_word = s:GetPreviousWord()
  
  if empty(prefix)
    return {
          \ 'prefix': '',
          \ 'prev_word': prev_word,
          \ 'prediction': '',
          \ 'completion': '',
          \ 'source': 'none'
          \ }
  endif
  
  let bigram_pred = ''
  let unigram_pred = ''
  let source = 'none'
  
  if !empty(prev_word)
    let bigram_pred = wordpred#predict#PredictWordBigram(prev_word, prefix)
  endif
  
  let unigram_pred = wordpred#predict#PredictWordUnigram(prefix)
  
  " Determine which prediction was used
  let prediction = wordpred#predict#PredictWord(prefix, bufnr('%'), prev_word)
  
  if !empty(prediction)
    if prediction ==# bigram_pred && !empty(bigram_pred)
      let source = 'bigram'
    elseif prediction ==# unigram_pred
      let source = 'unigram'
    endif
  endif
  
  return {
        \ 'prefix': prefix,
        \ 'prev_word': prev_word,
        \ 'bigram_prediction': bigram_pred,
        \ 'unigram_prediction': unigram_pred,
        \ 'prediction': prediction,
        \ 'completion': empty(prediction) ? '' : strpart(prediction, len(prefix)),
        \ 'source': source
        \ }
endfunction
