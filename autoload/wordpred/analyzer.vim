" analyzer.vim - Frequency analysis for word prediction
" Builds and maintains unigram and bigram frequency models

if exists('g:autoloaded_wordpred_analyzer')
  finish
endif
let g:autoloaded_wordpred_analyzer = 1

" Buffer-local storage for frequency data
" Structure: { bufnr: { 'word_freq': {}, 'bigram_freq': {}, 'last_tick': 0 } }
let s:buffer_data = {}

" Get or initialize data for a buffer
function! s:GetBufferData(bufnr) abort
  if !has_key(s:buffer_data, a:bufnr)
    let s:buffer_data[a:bufnr] = {
          \ 'word_freq': {},
          \ 'bigram_freq': {},
          \ 'last_tick': 0
          \ }
  endif
  return s:buffer_data[a:bufnr]
endfunction

" Extract words from text (3+ alphabetic characters)
function! s:ExtractWords(text) abort
  let words = []
  let word_pattern = '\<[a-zA-Z]\{3,}\>'
  let pos = 0
  
  while 1
    let match = matchstr(a:text, word_pattern, pos)
    if empty(match)
      break
    endif
    call add(words, tolower(match))
    let pos = match(a:text, word_pattern, pos) + len(match)
  endwhile
  
  return words
endfunction

" Update frequency models for current buffer
function! wordpred#analyzer#UpdateFrequencies(...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  
  " Check if buffer exists and is valid
  if !bufexists(bufnr) || !bufloaded(bufnr)
    return
  endif
  
  let data = s:GetBufferData(bufnr)
  let current_tick = getbufvar(bufnr, 'changedtick')
  
  " Skip if nothing changed
  if data.last_tick == current_tick
    return
  endif
  
  " Get all lines from buffer
  let lines = getbufline(bufnr, 1, '$')
  if empty(lines) || (len(lines) == 1 && empty(lines[0]))
    let data.last_tick = current_tick
    return
  endif
  let text = join(lines, ' ')
  
  " Clear existing frequencies
  let data.word_freq = {}
  let data.bigram_freq = {}
  
  " Extract words
  let words = s:ExtractWords(text)
  
  " Build unigram frequencies
  for word in words
    if has_key(data.word_freq, word)
      let data.word_freq[word] += 1
    else
      let data.word_freq[word] = 1
    endif
  endfor
  
  " Build bigram frequencies
  let word_count = len(words)
  for i in range(word_count - 1)
    let bigram = words[i] . '|' . words[i + 1]
    if has_key(data.bigram_freq, bigram)
      let data.bigram_freq[bigram] += 1
    else
      let data.bigram_freq[bigram] = 1
    endif
  endfor
  
  let data.last_tick = current_tick
endfunction

" Get frequency of a word (unigram)
function! wordpred#analyzer#GetWordFrequency(word, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let data = s:GetBufferData(bufnr)
  let word_lower = tolower(a:word)
  
  return get(data.word_freq, word_lower, 0)
endfunction

" Get frequency of a word pair (bigram)
function! wordpred#analyzer#GetBigramFrequency(word1, word2, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let data = s:GetBufferData(bufnr)
  let bigram = tolower(a:word1) . '|' . tolower(a:word2)
  
  return get(data.bigram_freq, bigram, 0)
endfunction

" Get all words matching a prefix
function! wordpred#analyzer#GetWordsWithPrefix(prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let data = s:GetBufferData(bufnr)
  let prefix_lower = tolower(a:prefix)
  let prefix_len = len(prefix_lower)
  let matches = {}
  
  for [word, freq] in items(data.word_freq)
    if len(word) > prefix_len && word[0:prefix_len-1] ==# prefix_lower
      let matches[word] = freq
    endif
  endfor
  
  return matches
endfunction

" Get all bigrams where first word matches and second word starts with prefix
function! wordpred#analyzer#GetBigramsWithPrefix(first_word, prefix, ...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let data = s:GetBufferData(bufnr)
  let first_lower = tolower(a:first_word)
  let prefix_lower = tolower(a:prefix)
  let prefix_len = len(prefix_lower)
  let matches = {}
  
  let search_pattern = first_lower . '|'
  
  for [bigram, freq] in items(data.bigram_freq)
    if stridx(bigram, search_pattern) == 0
      let parts = split(bigram, '|')
      if len(parts) == 2
        let second_word = parts[1]
        if len(second_word) > prefix_len && second_word[0:prefix_len-1] ==# prefix_lower
          let matches[second_word] = freq
        endif
      endif
    endif
  endfor
  
  return matches
endfunction

" Clear frequency data for a buffer
function! wordpred#analyzer#Clear(...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  if has_key(s:buffer_data, bufnr)
    call remove(s:buffer_data, bufnr)
  endif
endfunction

" Get statistics about the frequency model
function! wordpred#analyzer#GetStats(...) abort
  let bufnr = a:0 > 0 ? a:1 : bufnr('%')
  let data = s:GetBufferData(bufnr)
  
  return {
        \ 'unique_words': len(data.word_freq),
        \ 'unique_bigrams': len(data.bigram_freq),
        \ 'last_tick': data.last_tick
        \ }
endfunction

" Clean up data for buffers that no longer exist
function! wordpred#analyzer#CleanupDeletedBuffers() abort
  for bufnr in keys(s:buffer_data)
    if !bufexists(str2nr(bufnr))
      call remove(s:buffer_data, bufnr)
    endif
  endfor
endfunction
