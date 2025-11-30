-- performance.lua - Performance utilities and profiling for word prediction
-- Provides debouncing, throttling, and performance measurements

local M = {}

-- Performance statistics
local perf_stats = {
  update_count = 0,
  update_total_time = 0,
  predict_count = 0,
  predict_total_time = 0,
  display_count = 0,
  display_total_time = 0,
  last_update_time = 0,
  last_predict_time = 0
}

-- Debounce timers
local debounce_timers = {}
local throttle_last_call = {}

-- Measure execution time of a function
function M.measure(func, ...)
  local start = vim.loop.hrtime()
  local result = func(...)
  local elapsed = (vim.loop.hrtime() - start) / 1000000  -- Convert to milliseconds
  return result, elapsed
end

-- Debounce a function call
function M.debounce(func, delay_ms, key)
  -- Cancel existing timer if any
  if debounce_timers[key] then
    vim.fn.timer_stop(debounce_timers[key])
  end
  
  -- Create new timer
  debounce_timers[key] = vim.fn.timer_start(delay_ms, function()
    func()
    debounce_timers[key] = nil
  end)
end

-- Throttle a function call
function M.throttle(func, delay_ms, key)
  local current_time = vim.loop.hrtime() / 1000000
  local last_call = throttle_last_call[key] or 0
  local time_since_last = current_time - last_call
  
  if time_since_last >= delay_ms then
    throttle_last_call[key] = current_time
    func()
    return true
  end
  
  return false
end

-- Record update operation timing
function M.record_update(time_ms)
  perf_stats.update_count = perf_stats.update_count + 1
  perf_stats.update_total_time = perf_stats.update_total_time + time_ms
  perf_stats.last_update_time = time_ms
end

-- Record prediction operation timing
function M.record_predict(time_ms)
  perf_stats.predict_count = perf_stats.predict_count + 1
  perf_stats.predict_total_time = perf_stats.predict_total_time + time_ms
  perf_stats.last_predict_time = time_ms
end

-- Record display operation timing
function M.record_display(time_ms)
  perf_stats.display_count = perf_stats.display_count + 1
  perf_stats.display_total_time = perf_stats.display_total_time + time_ms
end

-- Get performance statistics
function M.get_stats()
  local stats = vim.deepcopy(perf_stats)
  
  -- Calculate averages
  if stats.update_count > 0 then
    stats.update_avg_time = stats.update_total_time / stats.update_count
  else
    stats.update_avg_time = 0
  end
  
  if stats.predict_count > 0 then
    stats.predict_avg_time = stats.predict_total_time / stats.predict_count
  else
    stats.predict_avg_time = 0
  end
  
  if stats.display_count > 0 then
    stats.display_avg_time = stats.display_total_time / stats.display_count
  else
    stats.display_avg_time = 0
  end
  
  return stats
end

-- Format performance statistics for display
function M.format_stats()
  local stats = M.get_stats()
  
  local lines = {
    '=== Word Prediction Performance Statistics ===',
    '',
    'Frequency Updates:',
    string.format('  Count: %d', stats.update_count),
    string.format('  Total time: %.2f ms', stats.update_total_time),
    string.format('  Average time: %.2f ms', stats.update_avg_time),
    string.format('  Last update: %.2f ms', stats.last_update_time),
    '',
    'Predictions:',
    string.format('  Count: %d', stats.predict_count),
    string.format('  Total time: %.2f ms', stats.predict_total_time),
    string.format('  Average time: %.2f ms', stats.predict_avg_time),
    string.format('  Last predict: %.2f ms', stats.last_predict_time),
    '',
    'Display Operations:',
    string.format('  Count: %d', stats.display_count),
    string.format('  Total time: %.2f ms', stats.display_total_time),
    string.format('  Average time: %.2f ms', stats.display_avg_time)
  }
  
  return table.concat(lines, '\n')
end

-- Reset performance statistics
function M.reset()
  perf_stats = {
    update_count = 0,
    update_total_time = 0,
    predict_count = 0,
    predict_total_time = 0,
    display_count = 0,
    display_total_time = 0,
    last_update_time = 0,
    last_predict_time = 0
  }
end

-- Check if performance monitoring is enabled
function M.is_enabled()
  return vim.g.wordpred_perf_monitor == 1
end

-- Optimized update check
function M.should_update(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local last_tick = vim.b[bufnr].wordpred_last_update_tick or 0
  
  local interval = vim.g.wordpred_update_interval or 10
  local changes_since_update = current_tick - last_tick
  
  return changes_since_update >= interval
end

-- Mark buffer as updated
function M.mark_updated(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr].wordpred_last_update_tick = vim.api.nvim_buf_get_changedtick(bufnr)
end

-- Get buffer word count for performance decisions
function M.get_buffer_size(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, ' ')
  return #text
end

-- Check if buffer is too large for real-time updates
function M.is_buffer_large(bufnr)
  local size = M.get_buffer_size(bufnr)
  local threshold = vim.g.wordpred_large_buffer_threshold or 100000
  return size > threshold
end

return M
