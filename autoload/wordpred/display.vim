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
      \ 'extmark_id': -1
      \ }

" Check if we're in Neovim with virtual text support
function! s:HasVirtualText() abort
  return has('nvim-0.5')
endfunction

" Check if we have text properties (Vim 8.1+)
function! s:HasTextProps() abort
  return has('textprop') && has('patch-8.1.0579')
endfunction

" Initialize namespace for Neovim extmarks
if s:HasVirtualText()
  let s:ns_id = nvim_create_namespace('wordpred')
endif

" Show prediction at current cursor position
function! wordpred#display#Show(prediction_text) abort
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
  
  if s:HasVirtualText()
    call s:ShowNeovim(a:prediction_text, bufnr, line, col)
  elseif s:HasTextProps()
    call s:ShowVim(a:prediction_text, bufnr, line + 1, col)
  else
    " Fallback: no visual display
    " Prediction is still stored and can be accepted
  endif
endfunction

" Show prediction using Neovim virtual text
function! s:ShowNeovim(text, bufnr, line, col) abort
  " Clear any existing prediction
  call nvim_buf_clear_namespace(a:bufnr, s:ns_id, 0, -1)
  
  " Get highlight group
  let hl_group = get(g:, 'wordpred_hl_group', 'Comment')
  
  " Set extmark with virtual text
  let opts = {
        \ 'virt_text': [[a:text, hl_group]],
        \ 'virt_text_pos': 'overlay',
        \ 'hl_mode': 'combine'
        \ }
  
  let extmark_id = nvim_buf_set_extmark(a:bufnr, s:ns_id, a:line, a:col, opts)
  let s:current_prediction.extmark_id = extmark_id
endfunction

" Show prediction using Vim text properties
function! s:ShowVim(text, bufnr, line, col) abort
  " Define property type if not exists
  if empty(prop_type_get('wordpred_prediction'))
    call prop_type_add('wordpred_prediction', {
          \ 'highlight': get(g:, 'wordpred_hl_group', 'Comment'),
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
  " This is a fallback since Vim can't easily show inline virtual text
  let w:wordpred_match_id = matchadd(get(g:, 'wordpred_hl_group', 'Comment'), 
        \ '\%' . a:line . 'l\%' . a:col . 'c', 0)
endfunction

" Hide current prediction
function! wordpred#display#Hide() abort
  if s:current_prediction.bufnr == -1
    return
  endif
  
  if s:HasVirtualText()
    call s:HideNeovim()
  elseif s:HasTextProps()
    call s:HideVim()
  endif
  
  " Reset state
  let s:current_prediction = {
        \ 'text': '',
        \ 'bufnr': -1,
        \ 'line': -1,
        \ 'col': -1,
        \ 'extmark_id': -1
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
  let prediction = wordpred#predict#GetCurrentPrediction()
  
  if !empty(prediction)
    call wordpred#display#Show(prediction)
  else
    call wordpred#display#Hide()
  endif
endfunction
