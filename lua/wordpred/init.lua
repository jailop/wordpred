-- init.lua - Main plugin initialization for Neovim
local M = {}

local analyzer = require('wordpred.analyzer')
local predict = require('wordpred.predict')
local display = require('wordpred.display')
local performance = require('wordpred.performance')

-- Track text change count for incremental updates
local change_count = 0

-- Default configuration
local default_config = {
  enabled = true,
  min_prefix_length = 1,
  update_interval = 10,
  bigram_weight = 2,
  hl_group = 'Comment',
  filetypes = {},
  accept_key = '<C-j>',
  cycle_next_key = '<C-n>',
  cycle_prev_key = '<C-p>',
  perf_monitor = false,
  debounce_delay = 100,
  large_buffer_threshold = 100000,
  show_source = true,
  max_candidates = 5,
  hl_group_bigram = 'Comment',
  hl_group_unigram = 'Comment'
}

local config = vim.deepcopy(default_config)

-- Check if word prediction is enabled for current buffer
local function is_enabled()
  if not config.enabled then
    return false
  end
  
  -- Check filetype filter if set
  if #config.filetypes > 0 then
    local ft = vim.bo.filetype
    local found = false
    for _, allowed_ft in ipairs(config.filetypes) do
      if ft == allowed_ft then
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  
  -- Check buffer-local override
  if vim.b.wordpred_enabled ~= nil then
    return vim.b.wordpred_enabled
  end
  
  return true
end

-- Update frequency model
local function update_model()
  if not is_enabled() then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Check if we should update
  if not performance.should_update(bufnr) then
    return
  end
  
  -- Skip large buffers
  if performance.is_buffer_large(bufnr) then
    return
  end
  
  -- Measure performance if monitoring enabled
  if performance.is_enabled() then
    local _, elapsed = performance.measure(analyzer.update_frequencies)
    performance.record_update(elapsed)
  else
    analyzer.update_frequencies()
  end
  
  -- Mark buffer as updated
  performance.mark_updated(bufnr)
end

-- Show prediction (debounced)
local function show_prediction_debounced()
  if not is_enabled() then
    display.hide()
    return
  end
  
  -- Measure performance if monitoring enabled
  if performance.is_enabled() then
    local _, elapsed = performance.measure(display.update)
    performance.record_display(elapsed)
  else
    display.update()
  end
end

-- Show prediction
local function show_prediction()
  if not is_enabled() then
    display.hide()
    return
  end
  
  -- Use debouncing if delay is set
  local delay = config.debounce_delay or 0
  if delay > 0 then
    performance.debounce(show_prediction_debounced, delay, 'show_prediction')
  else
    show_prediction_debounced()
  end
end

-- Accept prediction
local function accept_prediction()
  if display.is_shown() then
    display.accept()
  else
    -- If no prediction, insert default character
    local keys = vim.api.nvim_replace_termcodes('<C-j>', true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
  end
end

-- Cycle to next prediction
local function cycle_next()
  if display.is_shown() then
    display.cycle_next()
  else
    -- If no prediction, default behavior
    local keys = vim.api.nvim_replace_termcodes('<C-n>', true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
  end
end

-- Cycle to previous prediction
local function cycle_prev()
  if display.is_shown() then
    display.cycle_prev()
  else
    -- If no prediction, default behavior
    local keys = vim.api.nvim_replace_termcodes('<C-p>', true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
  end
end

-- Setup autocommands
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup('wordpred', { clear = true })
  
  -- Initialize on buffer enter
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      analyzer.update_frequencies()
    end
  })
  
  -- Update model on text change
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    callback = update_model
  })
  
  -- Show prediction on cursor movement in insert mode
  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    callback = show_prediction
  })
  
  -- Hide prediction when leaving insert mode
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    callback = function()
      display.hide()
    end
  })
  
  -- Cleanup deleted buffers
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function()
      analyzer.cleanup_deleted_buffers()
    end
  })
end

-- Setup key mapping
local function setup_keymaps()
  if config.accept_key ~= '' then
    vim.keymap.set('i', config.accept_key, accept_prediction, {
      silent = true,
      desc = 'Accept word prediction'
    })
  end
  
  if config.cycle_next_key ~= '' then
    vim.keymap.set('i', config.cycle_next_key, cycle_next, {
      silent = true,
      desc = 'Cycle to next prediction'
    })
  end
  
  if config.cycle_prev_key ~= '' then
    vim.keymap.set('i', config.cycle_prev_key, cycle_prev, {
      silent = true,
      desc = 'Cycle to previous prediction'
    })
  end
end

-- Setup commands
local function setup_commands()
  vim.api.nvim_create_user_command('WordPredEnable', function()
    config.enabled = true
  end, { desc = 'Enable word prediction' })
  
  vim.api.nvim_create_user_command('WordPredDisable', function()
    config.enabled = false
    display.hide()
  end, { desc = 'Disable word prediction' })
  
  vim.api.nvim_create_user_command('WordPredToggle', function()
    config.enabled = not config.enabled
    if not config.enabled then
      display.hide()
    end
    print('Word prediction: ' .. (config.enabled and 'enabled' or 'disabled'))
  end, { desc = 'Toggle word prediction' })
  
  vim.api.nvim_create_user_command('WordPredEnableBuffer', function()
    vim.b.wordpred_enabled = true
  end, { desc = 'Enable word prediction for current buffer' })
  
  vim.api.nvim_create_user_command('WordPredDisableBuffer', function()
    vim.b.wordpred_enabled = false
    display.hide()
  end, { desc = 'Disable word prediction for current buffer' })
  
  vim.api.nvim_create_user_command('WordPredStats', function()
    local stats = analyzer.get_stats()
    print(string.format('Words: %d, Bigrams: %d', stats.unique_words, stats.unique_bigrams))
  end, { desc = 'Show word prediction statistics' })
  
  vim.api.nvim_create_user_command('WordPredInfo', function()
    local info = predict.get_prediction_info()
    print(vim.inspect(info))
  end, { desc = 'Show current prediction info' })
  
  vim.api.nvim_create_user_command('WordPredCandidates', function()
    print(display.get_candidates_info())
  end, { desc = 'Show current candidates info' })
  
  vim.api.nvim_create_user_command('WordPredUpdate', function()
    analyzer.update_frequencies()
    print('Model updated')
  end, { desc = 'Update frequency model' })
  
  vim.api.nvim_create_user_command('WordPredClear', function()
    analyzer.clear()
    print('Model cleared')
  end, { desc = 'Clear frequency model' })
  
  -- Performance monitoring commands
  vim.api.nvim_create_user_command('WordPredPerfEnable', function()
    vim.g.wordpred_perf_monitor = 1
    print('Performance monitoring enabled')
  end, { desc = 'Enable performance monitoring' })
  
  vim.api.nvim_create_user_command('WordPredPerfDisable', function()
    vim.g.wordpred_perf_monitor = 0
    print('Performance monitoring disabled')
  end, { desc = 'Disable performance monitoring' })
  
  vim.api.nvim_create_user_command('WordPredPerfStats', function()
    print(performance.format_stats())
  end, { desc = 'Show performance statistics' })
  
  vim.api.nvim_create_user_command('WordPredPerfReset', function()
    performance.reset()
    print('Performance statistics reset')
  end, { desc = 'Reset performance statistics' })
end

-- Setup plugin with user configuration
function M.setup(user_config)
  -- Merge user config with defaults
  config = vim.tbl_deep_extend('force', default_config, user_config or {})
  
  -- Set global variables for compatibility
  vim.g.wordpred_enabled = config.enabled
  vim.g.wordpred_min_prefix_length = config.min_prefix_length
  vim.g.wordpred_update_interval = config.update_interval
  vim.g.wordpred_bigram_weight = config.bigram_weight
  vim.g.wordpred_hl_group = config.hl_group
  vim.g.wordpred_filetypes = config.filetypes
  vim.g.wordpred_perf_monitor = config.perf_monitor and 1 or 0
  vim.g.wordpred_debounce_delay = config.debounce_delay
  vim.g.wordpred_large_buffer_threshold = config.large_buffer_threshold
  vim.g.wordpred_show_source = config.show_source and 1 or 0
  vim.g.wordpred_max_candidates = config.max_candidates
  vim.g.wordpred_hl_group_bigram = config.hl_group_bigram
  vim.g.wordpred_hl_group_unigram = config.hl_group_unigram
  
  -- Setup plugin components
  setup_autocmds()
  setup_keymaps()
  setup_commands()
end

-- For backward compatibility, also expose modules
M.analyzer = analyzer
M.predict = predict
M.display = display
M.performance = performance

return M
