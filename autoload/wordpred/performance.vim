" performance.vim - Performance utilities and profiling for word prediction
" Provides debouncing, throttling, and performance measurements

if exists('g:autoloaded_wordpred_performance')
  finish
endif
let g:autoloaded_wordpred_performance = 1

" Performance statistics
let s:perf_stats = {
      \ 'update_count': 0,
      \ 'update_total_time': 0,
      \ 'predict_count': 0,
      \ 'predict_total_time': 0,
      \ 'display_count': 0,
      \ 'display_total_time': 0,
      \ 'last_update_time': 0,
      \ 'last_predict_time': 0
      \ }

" Debounce state
let s:debounce_timers = {}

" Get current time in milliseconds
function! s:GetTimeMs() abort
  return str2float(reltimestr(reltime())) * 1000
endfunction

" Debounce a function call
" Only executes after delay_ms of inactivity
function! wordpred#performance#Debounce(func, delay_ms, key) abort
  " Cancel existing timer if any
  if has_key(s:debounce_timers, a:key)
    try
      call timer_stop(s:debounce_timers[a:key])
    catch
    endtry
  endif
  
  " Create new timer
  let s:debounce_timers[a:key] = timer_start(a:delay_ms, a:func)
endfunction

" Throttle a function call
" Ensures function is called at most once every delay_ms
function! wordpred#performance#Throttle(func, delay_ms, key) abort
  let current_time = s:GetTimeMs()
  let last_call_key = 'throttle_last_' . a:key
  
  if !has_key(s:debounce_timers, last_call_key)
    let s:debounce_timers[last_call_key] = 0
  endif
  
  let time_since_last = current_time - s:debounce_timers[last_call_key]
  
  if time_since_last >= a:delay_ms
    let s:debounce_timers[last_call_key] = current_time
    call call(a:func, [])
    return 1
  endif
  
  return 0
endfunction

" Measure execution time of a function
function! wordpred#performance#Measure(func, args) abort
  let start = reltime()
  let result = call(a:func, a:args)
  let elapsed = str2float(reltimestr(reltime(start))) * 1000
  return [result, elapsed]
endfunction

" Record update operation timing
function! wordpred#performance#RecordUpdate(time_ms) abort
  let s:perf_stats.update_count += 1
  let s:perf_stats.update_total_time += a:time_ms
  let s:perf_stats.last_update_time = a:time_ms
endfunction

" Record prediction operation timing
function! wordpred#performance#RecordPredict(time_ms) abort
  let s:perf_stats.predict_count += 1
  let s:perf_stats.predict_total_time += a:time_ms
  let s:perf_stats.last_predict_time = a:time_ms
endfunction

" Record display operation timing
function! wordpred#performance#RecordDisplay(time_ms) abort
  let s:perf_stats.display_count += 1
  let s:perf_stats.display_total_time += a:time_ms
endfunction

" Get performance statistics
function! wordpred#performance#GetStats() abort
  let stats = copy(s:perf_stats)
  
  " Calculate averages
  if stats.update_count > 0
    let stats.update_avg_time = stats.update_total_time / stats.update_count
  else
    let stats.update_avg_time = 0
  endif
  
  if stats.predict_count > 0
    let stats.predict_avg_time = stats.predict_total_time / stats.predict_count
  else
    let stats.predict_avg_time = 0
  endif
  
  if stats.display_count > 0
    let stats.display_avg_time = stats.display_total_time / stats.display_count
  else
    let stats.display_avg_time = 0
  endif
  
  return stats
endfunction

" Format performance statistics for display
function! wordpred#performance#FormatStats() abort
  let stats = wordpred#performance#GetStats()
  
  let lines = []
  call add(lines, '=== Word Prediction Performance Statistics ===')
  call add(lines, '')
  call add(lines, 'Frequency Updates:')
  call add(lines, '  Count: ' . stats.update_count)
  call add(lines, '  Total time: ' . printf('%.2f', stats.update_total_time) . ' ms')
  call add(lines, '  Average time: ' . printf('%.2f', stats.update_avg_time) . ' ms')
  call add(lines, '  Last update: ' . printf('%.2f', stats.last_update_time) . ' ms')
  call add(lines, '')
  call add(lines, 'Predictions:')
  call add(lines, '  Count: ' . stats.predict_count)
  call add(lines, '  Total time: ' . printf('%.2f', stats.predict_total_time) . ' ms')
  call add(lines, '  Average time: ' . printf('%.2f', stats.predict_avg_time) . ' ms')
  call add(lines, '  Last predict: ' . printf('%.2f', stats.last_predict_time) . ' ms')
  call add(lines, '')
  call add(lines, 'Display Operations:')
  call add(lines, '  Count: ' . stats.display_count)
  call add(lines, '  Total time: ' . printf('%.2f', stats.display_total_time) . ' ms')
  call add(lines, '  Average time: ' . printf('%.2f', stats.display_avg_time) . ' ms')
  
  return join(lines, "\n")
endfunction

" Reset performance statistics
function! wordpred#performance#Reset() abort
  let s:perf_stats = {
        \ 'update_count': 0,
        \ 'update_total_time': 0,
        \ 'predict_count': 0,
        \ 'predict_total_time': 0,
        \ 'display_count': 0,
        \ 'display_total_time': 0,
        \ 'last_update_time': 0,
        \ 'last_predict_time': 0
        \ }
endfunction

" Check if performance monitoring is enabled
function! wordpred#performance#IsEnabled() abort
  return get(g:, 'wordpred_perf_monitor', 0)
endfunction

" Optimized update check - only update if buffer changed significantly
function! wordpred#performance#ShouldUpdate(bufnr) abort
  let current_tick = getbufvar(a:bufnr, 'changedtick')
  let last_tick = getbufvar(a:bufnr, 'wordpred_last_update_tick', 0)
  
  " Get update interval
  let interval = get(g:, 'wordpred_update_interval', 10)
  let changes_since_update = current_tick - last_tick
  
  return changes_since_update >= interval
endfunction

" Mark buffer as updated
function! wordpred#performance#MarkUpdated(bufnr) abort
  call setbufvar(a:bufnr, 'wordpred_last_update_tick', getbufvar(a:bufnr, 'changedtick'))
endfunction

" Get buffer word count for performance decisions
function! wordpred#performance#GetBufferSize(bufnr) abort
  let lines = getbufline(a:bufnr, 1, '$')
  let text = join(lines, ' ')
  return len(text)
endfunction

" Check if buffer is too large for real-time updates
function! wordpred#performance#IsBufferLarge(bufnr) abort
  let size = wordpred#performance#GetBufferSize(a:bufnr)
  let threshold = get(g:, 'wordpred_large_buffer_threshold', 100000)
  return size > threshold
endfunction
