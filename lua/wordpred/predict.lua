-- predict.lua - Prediction engine for word completion
-- Combines unigram and bigram models to predict word completions

local M = {}
local analyzer = require('wordpred.analyzer')

-- Get the word under cursor (current prefix being typed)
local function get_current_word()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Find start of word
  local start = col
  while start > 0 and line:sub(start, start):match('[a-zA-Z]') do
    start = start - 1
  end
  
  -- Extract the word prefix
  if start < col then
    return line:sub(start + 1, col)
  end
  
  return ''
end

-- Get the previous word before cursor
local function get_previous_word()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Find start of current word
  local pos = col
  while pos > 0 and line:sub(pos, pos):match('[a-zA-Z]') do
    pos = pos - 1
  end
  
  -- Skip whitespace before current word
  while pos > 0 and line:sub(pos, pos):match('%s') do
    pos = pos - 1
  end
  
  -- Find end of previous word
  local end_pos = pos
  if end_pos == 0 then
    return ''
  end
  
  -- Find start of previous word
  local start = end_pos
  while start > 0 and line:sub(start, start):match('[a-zA-Z]') do
    start = start - 1
  end
  
  if start < end_pos then
    return line:sub(start + 1, end_pos)
  end
  
  return ''
end

-- Predict word using unigram model (frequency-based)
function M.predict_word_unigram(prefix, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local min_prefix = vim.g.wordpred_min_prefix_length or 1
  if #prefix < min_prefix then
    return ''
  end
  
  -- Get all words matching prefix
  local matches = analyzer.get_words_with_prefix(prefix, bufnr)
  
  if vim.tbl_isempty(matches) then
    return ''
  end
  
  -- Find word with highest frequency
  local best_word = ''
  local max_freq = 0
  
  for word, freq in pairs(matches) do
    if freq > max_freq then
      max_freq = freq
      best_word = word
    end
  end
  
  return best_word
end

-- Predict word using bigram model (context-aware)
function M.predict_word_bigram(prev_word, prefix, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if prev_word == '' or #prefix < 1 then
    return ''
  end
  
  -- Get all bigrams matching the pattern
  local matches = analyzer.get_bigrams_with_prefix(prev_word, prefix, bufnr)
  
  if vim.tbl_isempty(matches) then
    return ''
  end
  
  -- Find word with highest bigram frequency
  local best_word = ''
  local max_freq = 0
  
  for word, freq in pairs(matches) do
    if freq > max_freq then
      max_freq = freq
      best_word = word
    end
  end
  
  return best_word
end

-- Combined prediction: bigram + unigram with weighting
function M.predict_word(prefix, bufnr, prev_word)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  prev_word = prev_word or ''
  
  local min_prefix = vim.g.wordpred_min_prefix_length or 1
  if #prefix < min_prefix then
    return ''
  end
  
  -- Try bigram prediction first (context-aware)
  local bigram_pred = ''
  if prev_word ~= '' then
    bigram_pred = M.predict_word_bigram(prev_word, prefix, bufnr)
  end
  
  -- Try unigram prediction
  local unigram_pred = M.predict_word_unigram(prefix, bufnr)
  
  -- If both predictions exist, choose based on frequency weighting
  if bigram_pred ~= '' and unigram_pred ~= '' then
    local bigram_freq = analyzer.get_bigram_frequency(prev_word, bigram_pred, bufnr)
    local unigram_freq = analyzer.get_word_frequency(unigram_pred, bufnr)
    local bigram_weight = vim.g.wordpred_bigram_weight or 2
    
    -- Prefer bigram if its weighted frequency is higher
    if bigram_freq * bigram_weight >= unigram_freq then
      return bigram_pred
    else
      return unigram_pred
    end
  end
  
  -- Return whichever prediction exists
  if bigram_pred ~= '' then
    return bigram_pred
  end
  
  return unigram_pred
end

-- Get prediction for current cursor position
function M.get_current_prediction()
  local prefix = get_current_word()
  
  if prefix == '' then
    return ''
  end
  
  local prev_word = get_previous_word()
  local prediction = M.predict_word(prefix, vim.api.nvim_get_current_buf(), prev_word)
  
  -- Return only the completion part (remove the prefix)
  if prediction ~= '' and prediction:lower() ~= prefix:lower() then
    return prediction:sub(#prefix + 1)
  end
  
  return ''
end

-- Get full prediction info for debugging/display
function M.get_prediction_info()
  local prefix = get_current_word()
  local prev_word = get_previous_word()
  
  if prefix == '' then
    return {
      prefix = '',
      prev_word = prev_word,
      prediction = '',
      completion = '',
      source = 'none'
    }
  end
  
  local bigram_pred = ''
  local unigram_pred = ''
  local source = 'none'
  
  if prev_word ~= '' then
    bigram_pred = M.predict_word_bigram(prev_word, prefix)
  end
  
  unigram_pred = M.predict_word_unigram(prefix)
  
  -- Determine which prediction was used
  local prediction = M.predict_word(prefix, vim.api.nvim_get_current_buf(), prev_word)
  
  if prediction ~= '' then
    if prediction == bigram_pred and bigram_pred ~= '' then
      source = 'bigram'
    elseif prediction == unigram_pred then
      source = 'unigram'
    end
  end
  
  return {
    prefix = prefix,
    prev_word = prev_word,
    bigram_prediction = bigram_pred,
    unigram_prediction = unigram_pred,
    prediction = prediction,
    completion = prediction ~= '' and prediction:sub(#prefix + 1) or '',
    source = source
  }
end

return M
