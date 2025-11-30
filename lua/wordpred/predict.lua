-- predict.lua - Prediction engine for word completion
-- Combines unigram and bigram models to predict word completions

local M = {}
local analyzer = require('wordpred.analyzer')

-- Get the word under cursor (current prefix being typed)
function M.get_current_word()
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
function M.get_previous_word()
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
    return line:sub(start + 1, end_pos):lower()
  end
  
  return ''
end

-- Get multiple prediction candidates (unigram model)
function M.get_candidates_unigram(prefix, bufnr, max_candidates)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  max_candidates = max_candidates or vim.g.wordpred_max_candidates or 5
  
  local min_prefix = vim.g.wordpred_min_prefix_length or 1
  if #prefix < min_prefix then
    return {}
  end
  
  -- Get all words matching prefix
  local matches = analyzer.get_words_with_prefix(prefix, bufnr)
  
  if vim.tbl_isempty(matches) then
    return {}
  end
  
  -- Convert to list and sort by frequency
  local candidates = {}
  for word, freq in pairs(matches) do
    table.insert(candidates, {word = word, freq = freq, source = 'unigram'})
  end
  
  table.sort(candidates, function(a, b) return a.freq > b.freq end)
  
  -- Return top N candidates
  local result = {}
  for i = 1, math.min(max_candidates, #candidates) do
    table.insert(result, candidates[i])
  end
  
  return result
end

-- Predict word using unigram model (frequency-based)
function M.predict_word_unigram(prefix, bufnr)
  local candidates = M.get_candidates_unigram(prefix, bufnr, 1)
  return #candidates > 0 and candidates[1].word or ''
end

-- Get multiple prediction candidates (bigram model)
function M.get_candidates_bigram(prev_word, prefix, bufnr, max_candidates)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  max_candidates = max_candidates or vim.g.wordpred_max_candidates or 5
  
  if prev_word == '' or #prefix < 1 then
    return {}
  end
  
  -- Get all bigrams matching the pattern
  local matches = analyzer.get_bigrams_with_prefix(prev_word, prefix, bufnr)
  
  if vim.tbl_isempty(matches) then
    return {}
  end
  
  -- Convert to list and sort by frequency
  local candidates = {}
  for word, freq in pairs(matches) do
    table.insert(candidates, {word = word, freq = freq, source = 'bigram'})
  end
  
  table.sort(candidates, function(a, b) return a.freq > b.freq end)
  
  -- Return top N candidates
  local result = {}
  for i = 1, math.min(max_candidates, #candidates) do
    table.insert(result, candidates[i])
  end
  
  return result
end

-- Predict word using bigram model (context-aware)
function M.predict_word_bigram(prev_word, prefix, bufnr)
  local candidates = M.get_candidates_bigram(prev_word, prefix, bufnr, 1)
  return #candidates > 0 and candidates[1].word or ''
end

-- Get multiple combined prediction candidates
function M.get_candidates(prefix, bufnr, prev_word, max_candidates)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  prev_word = prev_word or ''
  max_candidates = max_candidates or vim.g.wordpred_max_candidates or 5
  
  local min_prefix = vim.g.wordpred_min_prefix_length or 1
  if #prefix < min_prefix then
    return {}
  end
  
  -- Get candidates from both models
  local bigram_candidates = {}
  if prev_word ~= '' then
    bigram_candidates = M.get_candidates_bigram(prev_word, prefix, bufnr, max_candidates)
  end
  
  local unigram_candidates = M.get_candidates_unigram(prefix, bufnr, max_candidates)
  
  -- Merge and sort by weighted score
  local all_candidates = {}
  local bigram_weight = vim.g.wordpred_bigram_weight or 2
  
  -- Add bigram candidates with weighted score
  for _, candidate in ipairs(bigram_candidates) do
    local word = candidate.word
    local score = candidate.freq * bigram_weight
    all_candidates[word] = {
      word = word,
      score = score,
      source = 'bigram',
      freq = candidate.freq
    }
  end
  
  -- Add or merge unigram candidates
  for _, candidate in ipairs(unigram_candidates) do
    local word = candidate.word
    if all_candidates[word] then
      -- Word exists from bigram, compare scores
      if candidate.freq > all_candidates[word].score then
        all_candidates[word].score = candidate.freq
        all_candidates[word].source = 'unigram'
      end
    else
      all_candidates[word] = {
        word = word,
        score = candidate.freq,
        source = 'unigram',
        freq = candidate.freq
      }
    end
  end
  
  -- Convert to list and sort by score
  local result = {}
  for _, candidate in pairs(all_candidates) do
    table.insert(result, candidate)
  end
  
  table.sort(result, function(a, b) return a.score > b.score end)
  
  -- Return top N
  local final = {}
  for i = 1, math.min(max_candidates, #result) do
    table.insert(final, result[i])
  end
  
  return final
end

-- Combined prediction: bigram + unigram with weighting
function M.predict_word(prefix, bufnr, prev_word)
  local candidates = M.get_candidates(prefix, bufnr, prev_word, 1)
  return #candidates > 0 and candidates[1].word or ''
end

-- Get prediction for current cursor position
function M.get_current_prediction()
  local prefix = M.get_current_word()
  
  if prefix == '' then
    return ''
  end
  
  local prev_word = M.get_previous_word()
  local prediction = M.predict_word(prefix, vim.api.nvim_get_current_buf(), prev_word)
  
  -- Return only the completion part (remove the prefix)
  if prediction ~= '' and prediction:lower() ~= prefix:lower() then
    return prediction:sub(#prefix + 1)
  end
  
  return ''
end

-- Get full prediction info for debugging/display
function M.get_prediction_info()
  local prefix = M.get_current_word()
  local prev_word = M.get_previous_word()
  
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
