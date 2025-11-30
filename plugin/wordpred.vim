" wordpred.vim - Main plugin file for word prediction
" Integrates analyzer, predictor, and display modules

if exists('g:loaded_wordpred')
  finish
endif
let g:loaded_wordpred = 1

" Default configuration
if !exists('g:wordpred_enabled')
  let g:wordpred_enabled = 1
endif

if !exists('g:wordpred_min_prefix_length')
  let g:wordpred_min_prefix_length = 1
endif

if !exists('g:wordpred_update_interval')
  let g:wordpred_update_interval = 10
endif

if !exists('g:wordpred_bigram_weight')
  let g:wordpred_bigram_weight = 2
endif

if !exists('g:wordpred_hl_group')
  let g:wordpred_hl_group = 'Comment'
endif

if !exists('g:wordpred_filetypes')
  let g:wordpred_filetypes = []
endif

if !exists('g:wordpred_accept_key')
  let g:wordpred_accept_key = '<Tab>'
endif

if !exists('g:wordpred_cycle_next_key')
  let g:wordpred_cycle_next_key = '<C-n>'
endif

if !exists('g:wordpred_cycle_prev_key')
  let g:wordpred_cycle_prev_key = '<C-p>'
endif

if !exists('g:wordpred_show_source')
  let g:wordpred_show_source = 0
endif

if !exists('g:wordpred_max_candidates')
  let g:wordpred_max_candidates = 5
endif

if !exists('g:wordpred_hl_group_bigram')
  let g:wordpred_hl_group_bigram = 'Comment'
endif

if !exists('g:wordpred_hl_group_unigram')
  let g:wordpred_hl_group_unigram = 'Comment'
endif

if !exists('g:wordpred_perf_monitor')
  let g:wordpred_perf_monitor = 0
endif

if !exists('g:wordpred_debounce_delay')
  let g:wordpred_debounce_delay = 100
endif

if !exists('g:wordpred_large_buffer_threshold')
  let g:wordpred_large_buffer_threshold = 100000
endif

" Track text change count for incremental updates
let s:change_count = 0

" Check if word prediction is enabled for current buffer
function! s:IsEnabled() abort
  if !g:wordpred_enabled
    return 0
  endif
  
  " Check filetype filter if set
  if !empty(g:wordpred_filetypes)
    let ft = &filetype
    if index(g:wordpred_filetypes, ft) == -1
      return 0
    endif
  endif
  
  " Check buffer-local override
  if exists('b:wordpred_enabled')
    return b:wordpred_enabled
  endif
  
  return 1
endfunction

" Update frequency model
function! s:UpdateModel() abort
  if !s:IsEnabled()
    return
  endif
  
  let bufnr = bufnr('%')
  
  " Check if we should update based on performance considerations
  if !wordpred#performance#ShouldUpdate(bufnr)
    return
  endif
  
  " Skip large buffers for real-time updates
  if wordpred#performance#IsBufferLarge(bufnr)
    return
  endif
  
  " Measure performance if monitoring enabled
  if wordpred#performance#IsEnabled()
    let [result, elapsed] = wordpred#performance#Measure(
          \ function('wordpred#analyzer#UpdateFrequencies'), [])
    call wordpred#performance#RecordUpdate(elapsed)
  else
    call wordpred#analyzer#UpdateFrequencies()
  endif
  
  " Mark buffer as updated
  call wordpred#performance#MarkUpdated(bufnr)
endfunction

" Show prediction (with optional debouncing)
function! s:ShowPredictionDebounced(timer) abort
  if !s:IsEnabled()
    call wordpred#display#Hide()
    return
  endif
  
  " Measure performance if monitoring enabled
  if wordpred#performance#IsEnabled()
    let start = reltime()
    call wordpred#display#Update()
    let elapsed = str2float(reltimestr(reltime(start))) * 1000
    call wordpred#performance#RecordDisplay(elapsed)
  else
    call wordpred#display#Update()
  endif
endfunction

" Show prediction
function! s:ShowPrediction() abort
  if !s:IsEnabled()
    call wordpred#display#Hide()
    return
  endif
  
  " Use debouncing if delay is set
  let delay = get(g:, 'wordpred_debounce_delay', 0)
  if delay > 0
    call wordpred#performance#Debounce(
          \ function('s:ShowPredictionDebounced'),
          \ delay,
          \ 'show_prediction')
  else
    call s:ShowPredictionDebounced(0)
  endif
endfunction

" Accept prediction
function! s:AcceptPrediction() abort
  if wordpred#display#IsShown()
    call wordpred#display#Accept()
    return ''
  endif
  
  " If no prediction, return default character
  return "\<C-j>"
endfunction

" Cycle to next prediction
function! s:CycleNext() abort
  if wordpred#display#IsShown()
    call wordpred#display#CycleNext()
    return ''
  endif
  
  " If no prediction, return default behavior
  return "\<C-n>"
endfunction

" Cycle to previous prediction
function! s:CyclePrev() abort
  if wordpred#display#IsShown()
    call wordpred#display#CyclePrev()
    return ''
  endif
  
  " If no prediction, return default behavior
  return "\<C-p>"
endfunction

" Setup autocommands
augroup wordpred
  autocmd!
  
  " Initialize on buffer enter
  autocmd BufEnter * call wordpred#analyzer#UpdateFrequencies()
  
  " Update model on text change
  autocmd TextChanged,TextChangedI * call s:UpdateModel()
  
  " Show prediction on cursor movement in insert mode
  autocmd CursorMovedI * call s:ShowPrediction()
  
  " Hide prediction when leaving insert mode
  autocmd InsertLeave * call wordpred#display#Hide()
  
  " Cleanup deleted buffers
  autocmd BufDelete * call wordpred#analyzer#CleanupDeletedBuffers()
augroup END

" Key mapping for accepting prediction
if !empty(g:wordpred_accept_key)
  execute 'inoremap <silent><expr> ' . g:wordpred_accept_key . ' <SID>AcceptPrediction()'
endif

" Key mappings for cycling through candidates
if !empty(g:wordpred_cycle_next_key)
  execute 'inoremap <silent><expr> ' . g:wordpred_cycle_next_key . ' <SID>CycleNext()'
endif

if !empty(g:wordpred_cycle_prev_key)
  execute 'inoremap <silent><expr> ' . g:wordpred_cycle_prev_key . ' <SID>CyclePrev()'
endif

" Commands
command! WordPredEnable let g:wordpred_enabled = 1
command! WordPredDisable let g:wordpred_enabled = 0 | call wordpred#display#Hide()
command! WordPredToggle let g:wordpred_enabled = !g:wordpred_enabled | 
      \ if !g:wordpred_enabled | call wordpred#display#Hide() | endif

command! WordPredEnableBuffer let b:wordpred_enabled = 1
command! WordPredDisableBuffer let b:wordpred_enabled = 0 | call wordpred#display#Hide()

command! WordPredStats echo wordpred#analyzer#GetStats()
command! WordPredInfo echo wordpred#predict#GetPredictionInfo()
command! WordPredCandidates echo wordpred#display#GetCandidatesInfo()
command! WordPredUpdate call wordpred#analyzer#UpdateFrequencies() | echo 'Model updated'
command! WordPredClear call wordpred#analyzer#Clear() | echo 'Model cleared'

" Performance monitoring commands
command! WordPredPerfEnable let g:wordpred_perf_monitor = 1 | echo 'Performance monitoring enabled'
command! WordPredPerfDisable let g:wordpred_perf_monitor = 0 | echo 'Performance monitoring disabled'
command! WordPredPerfStats echo wordpred#performance#FormatStats()
command! WordPredPerfReset call wordpred#performance#Reset() | echo 'Performance statistics reset'
