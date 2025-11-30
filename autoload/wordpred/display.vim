" display.vim - Display management for word predictions
" Handles showing and hiding predictions as virtual text or highlights

if exists('g:autoloaded_wordpred_display')
  finish
endif
let g:autoloaded_wordpred_display = 1

" Store current prediction state
let s:current_prediction = {
      \ 'text': '',
      \ 'bufnr': -1,
      \ 'line': -1,
      \ 'col': -1,
      \ 'extmark_id': -1,
      \ 'candidates': [],
      \ 'current_index': 0,
      \ 'source': 'none'
      \ }

" Check if we're in Neovim with virtual text support
function! s:HasVirtualText() abort
  return has('nvim-0.5')
endfunction

" Check if we have text properties (Vim 8.1+)
function! s:HasTextProps() abort
  return has('textprop') && has('patch-8.1.0579')
endfunction

" Check if we have popup windows (Vim 8.2+)
function! s:HasPopup() abort
  return has('patch-8.2.0286') && exists('*popup_create')
endfunction

" Initialize namespace for Neovim extmarks
if s:HasVirtualText()
  let s:ns_id = nvim_create_namespace('wordpred')
endif

" Show prediction at current cursor position with source info
function! wordpred#display#Show(prediction_text, ...) abort
  let source = a:0 > 0 ? a:1 : 'unknown'
  
  if empty(a:prediction_text)
    call wordpred#display#Hide()
    return
  endif
  
  let bufnr = bufnr('%')
  let pos = getcurpos()
  let line = pos[1] - 1  " 0-indexed for Neovim
  let col = pos[2]
  
  " Store prediction state
  let s:current_prediction.text = a:prediction_text
  let s:current_prediction.bufnr = bufnr
  let s:current_prediction.line = line
  let s:current_prediction.col = col
  let s:current_prediction.source = source
  
  if s:HasVirtualText()
    call s:ShowNeovim(a:prediction_text, bufnr, line, col, source)
  elseif s:HasPopup()
    call s:ShowVimPopup(a:prediction_text, bufnr, line + 1, col, source)
  elseif s:HasTextProps()
    call s:ShowVim(a:prediction_text, bufnr, line + 1, col, source)
  else
    " Fallback: no visual display
    " Prediction is still stored and can be accepted
  endif
endfunction

" Show prediction using Neovim virtual text
function! s:ShowNeovim(text, bufnr, line, col, source) abort
  " Clear any existing prediction
  call nvim_buf_clear_namespace(a:bufnr, s:ns_id, 0, -1)
  
  " Get highlight group based on source
  let hl_group = s:GetHighlightGroup(a:source)
  
  " Add source indicator if enabled
  let display_text = a:text
  if get(g:, 'wordpred_show_source', 1)
    let indicator = a:source ==# 'bigram' ? '⚡' : '●'
    let display_text = a:text . ' ' . indicator
  endif
  
  " Set extmark with virtual text
  let opts = {
        \ 'virt_text': [[display_text, hl_group]],
        \ 'virt_text_pos': 'overlay',
        \ 'hl_mode': 'combine'
        \ }
  
  let extmark_id = nvim_buf_set_extmark(a:bufnr, s:ns_id, a:line, a:col, opts)
  let s:current_prediction.extmark_id = extmark_id
endfunction

" Get highlight group based on prediction source
function! s:GetHighlightGroup(source) abort
  if a:source ==# 'bigram'
    let hl = get(g:, 'wordpred_hl_group_bigram', get(g:, 'wordpred_hl_group', 'Comment'))
  else
    let hl = get(g:, 'wordpred_hl_group_unigram', get(g:, 'wordpred_hl_group', 'Comment'))
  endif
  
  " Check if highlight group exists, fallback to safe default
  if hlexists(hl)
    return hl
  endif
  
  " Try common fallbacks
  if hlexists('Comment')
    return 'Comment'
  elseif hlexists('NonText')
    return 'NonText'
  else
    return 'Normal'
  endif
endfunction

" Show prediction using Vim popup windows (Vim 8.2+)
function! s:ShowVimPopup(text, bufnr, line, col, source) abort
  " Close any existing popup
  call s:HideVimPopup()
  
  " Get highlight group
  let hl_group = s:GetHighlightGroup(a:source)
  
  " Add source indicator if enabled
  let display_text = a:text
  if get(g:, 'wordpred_show_source', 1)
    let indicator = a:source ==# 'bigram' ? '⚡' : '●'
    let display_text = a:text . ' ' . indicator
  endif
  
  " Create popup at cursor position
  let opts = {
        \ 'line': 'cursor',
        \ 'col': 'cursor',
        \ 'pos': 'topleft',
        \ 'wrap': 0,
        \ 'highlight': hl_group,
        \ 'zindex': 200,
        \ 'moved': 'any'
        \ }
  
  let w:wordpred_popup_id = popup_create(display_text, opts)
endfunction

" Hide popup window
function! s:HideVimPopup() abort
  if exists('w:wordpred_popup_id')
    try
      call popup_close(w:wordpred_popup_id)
    catch
    endtry
    unlet w:wordpred_popup_id
  endif
endfunction

" Show prediction using Vim text properties
function! s:ShowVim(text, bufnr, line, col, source) abort
  " Get highlight group based on source
  let hl_group = s:GetHighlightGroup(a:source)
  
  " Define property type if not exists
  if empty(prop_type_get('wordpred_prediction'))
    call prop_type_add('wordpred_prediction', {
          \ 'highlight': hl_group,
          \ 'priority': 0
          \ })
  endif
  
  " Note: Vim's text properties are more limited than Neovim's virtual text
  " We'll use a simpler approach with matchaddpos
  if exists('w:wordpred_match_id')
    try
      call matchdelete(w:wordpred_match_id)
    catch
    endtry
  endif
  
  " Highlight the cursor position to show where prediction would appear
  let w:wordpred_match_id = matchadd(hl_group, 
        \ '\%' . a:line . 'l\%' . a:col . 'c', 0)
endfunction

" Hide current prediction
function! wordpred#display#Hide() abort
  if s:current_prediction.bufnr == -1
    return
  endif
  
  if s:HasVirtualText()
    call s:HideNeovim()
  elseif s:HasPopup()
    call s:HideVimPopup()
  elseif s:HasTextProps()
    call s:HideVim()
  endif
  
  " Reset state
  let s:current_prediction = {
        \ 'text': '',
        \ 'bufnr': -1,
        \ 'line': -1,
        \ 'col': -1,
        \ 'extmark_id': -1,
        \ 'candidates': [],
        \ 'current_index': 0,
        \ 'source': 'none'
        \ }
endfunction

" Hide prediction in Neovim
function! s:HideNeovim() abort
  if s:current_prediction.bufnr != -1
    try
      call nvim_buf_clear_namespace(s:current_prediction.bufnr, s:ns_id, 0, -1)
    catch
    endtry
  endif
endfunction

" Hide prediction in Vim
function! s:HideVim() abort
  if exists('w:wordpred_match_id')
    try
      call matchdelete(w:wordpred_match_id)
    catch
    endtry
    unlet w:wordpred_match_id
  endif
endfunction

" Accept current prediction (insert the text)
function! wordpred#display#Accept() abort
  if empty(s:current_prediction.text)
    return 0
  endif
  
  " Insert the prediction text
  let text = s:current_prediction.text
  call wordpred#display#Hide()
  
  " Insert in insert mode
  if mode() ==# 'i'
    call feedkeys(text, 'n')
  else
    " If not in insert mode, just insert at cursor
    execute "normal! a" . text
  endif
  
  return 1
endfunction

" Get current prediction text
function! wordpred#display#GetCurrent() abort
  return s:current_prediction.text
endfunction

" Check if a prediction is currently shown
function! wordpred#display#IsShown() abort
  return !empty(s:current_prediction.text)
endfunction

" Update prediction (convenience function)
function! wordpred#display#Update() abort
  " Get prediction from predict module
  let prefix = wordpred#predict#GetCurrentWord()
  let prev_word = wordpred#predict#GetPreviousWord()
  
  if empty(prefix)
    call wordpred#display#Hide()
    return
  endif
  
  " Get multiple candidates
  let candidates = wordpred#predict#GetCandidates(prefix, bufnr('%'), prev_word)
  
  if empty(candidates)
    call wordpred#display#Hide()
    return
  endif
  
  " Store candidates and show first one
  let s:current_prediction.candidates = candidates
  let s:current_prediction.current_index = 0
  
  let prediction = candidates[0]
  let completion = strpart(prediction.word, len(prefix))
  
  if !empty(completion)
    call wordpred#display#Show(completion, prediction.source)
  else
    call wordpred#display#Hide()
  endif
endfunction

" Cycle to next prediction candidate
function! wordpred#display#CycleNext() abort
  if empty(s:current_prediction.candidates)
    return
  endif
  
  let s:current_prediction.current_index = 
        \ (s:current_prediction.current_index + 1) % len(s:current_prediction.candidates)
  
  call s:ShowCurrentCandidate()
endfunction

" Cycle to previous prediction candidate
function! wordpred#display#CyclePrev() abort
  if empty(s:current_prediction.candidates)
    return
  endif
  
  let s:current_prediction.current_index = 
        \ (s:current_prediction.current_index + len(s:current_prediction.candidates) - 1) 
        \ % len(s:current_prediction.candidates)
  
  call s:ShowCurrentCandidate()
endfunction

" Show current candidate from the list
function! s:ShowCurrentCandidate() abort
  if empty(s:current_prediction.candidates)
    return
  endif
  
  let prefix = wordpred#predict#GetCurrentWord()
  let candidate = s:current_prediction.candidates[s:current_prediction.current_index]
  let completion = strpart(candidate.word, len(prefix))
  
  if !empty(completion)
    call wordpred#display#Show(completion, candidate.source)
  endif
endfunction

" Get current candidate info (for display/debugging)
function! wordpred#display#GetCandidatesInfo() abort
  if empty(s:current_prediction.candidates)
    return 'No candidates'
  endif
  
  let info = printf('[%d/%d] ', 
        \ s:current_prediction.current_index + 1,
        \ len(s:current_prediction.candidates))
  
  let candidate = s:current_prediction.candidates[s:current_prediction.current_index]
  let info .= printf('%s (%s)', candidate.word, candidate.source)
  
  return info
endfunction
