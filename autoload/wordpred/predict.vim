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

" Get multiple prediction candidates (bigram model)
function! wordpred#predict#GetCandidatesBigram(prev_word, prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let max_candidates = a:0 > 1 ? a:2 : get(g:, 'wordpred_max_candidates', 5)
  
  if empty(a:prev_word) || len(a:prefix) < 1
    return []
  endif
  
  " Get all bigrams matching the pattern
  let matches = wordpred#analyzer#GetBigramsWithPrefix(a:prev_word, a:prefix, bufnr)
  
  if empty(matches)
    return []
  endif
  
  " Sort by frequency (descending)
  let candidates = []
  for [word, freq] in items(matches)
    call add(candidates, {'word': word, 'freq': freq, 'source': 'bigram'})
  endfor
  
  call sort(candidates, {a, b -> b.freq - a.freq})
  
  " Return top N candidates
  return candidates[:max_candidates - 1]
endfunction

" Predict word using bigram model (context-aware)
function! wordpred#predict#PredictWordBigram(prev_word, prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  
  let candidates = wordpred#predict#GetCandidatesBigram(a:prev_word, a:prefix, bufnr, 1)
  
  return empty(candidates) ? '' : candidates[0].word
endfunction

" Get multiple combined prediction candidates
function! wordpred#predict#GetCandidates(prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let prev_word = a:0 > 1 ? a:2 : ''
  let max_candidates = a:0 > 2 ? a:3 : get(g:, 'wordpred_max_candidates', 5)
  
  let min_prefix = get(g:, 'wordpred_min_prefix_length', 1)
  if len(a:prefix) < min_prefix
    return []
  endif
  
  " Get candidates from both models
  let bigram_candidates = []
  if !empty(prev_word)
    let bigram_candidates = wordpred#predict#GetCandidatesBigram(prev_word, a:prefix, bufnr, max_candidates)
  endif
  
  let unigram_candidates = wordpred#predict#GetCandidatesUnigram(a:prefix, bufnr, max_candidates)
  
  " Merge and sort by weighted score
  let all_candidates = {}
  let bigram_weight = get(g:, 'wordpred_bigram_weight', 2)
  
  " Add bigram candidates with weighted score
  for candidate in bigram_candidates
    let word = candidate.word
    let score = candidate.freq * bigram_weight
    let all_candidates[word] = {
          \ 'word': word,
          \ 'score': score,
          \ 'source': 'bigram',
          \ 'freq': candidate.freq
          \ }
  endfor
  
  " Add or merge unigram candidates
  for candidate in unigram_candidates
    let word = candidate.word
    if has_key(all_candidates, word)
      " Word exists from bigram, compare scores
      if candidate.freq > all_candidates[word].score
        let all_candidates[word].score = candidate.freq
        let all_candidates[word].source = 'unigram'
      endif
    else
      let all_candidates[word] = {
            \ 'word': word,
            \ 'score': candidate.freq,
            \ 'source': 'unigram',
            \ 'freq': candidate.freq
            \ }
    endif
  endfor
  
  " Convert to list and sort by score
  let result = values(all_candidates)
  call sort(result, {a, b -> float2nr(b.score - a.score)})
  
  return result[:max_candidates - 1]
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
  let prefix = wordpred#predict#GetCurrentWord()
  
  if empty(prefix)
    return ''
  endif
  
  let prev_word = wordpred#predict#GetPreviousWord()
  let prediction = wordpred#predict#PredictWord(prefix, bufnr('%'), prev_word)
  
  " Return only the completion part (remove the prefix)
  if !empty(prediction) && prediction !=? prefix
    return strpart(prediction, len(prefix))
  endif
  
  return ''
endfunction

" Get full prediction info for debugging/display
function! wordpred#predict#GetPredictionInfo() abort
  let prefix = wordpred#predict#GetCurrentWord()
  let prev_word = wordpred#predict#GetPreviousWord()
  
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
