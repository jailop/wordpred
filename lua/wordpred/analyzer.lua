-- analyzer.lua - Frequency analysis for word prediction
-- Builds and maintains unigram and bigram frequency models

local M = {}

-- Buffer-local storage for frequency data
-- Structure: { bufnr: { word_freq = {}, bigram_freq = {}, last_tick = 0 } }
local buffer_data = {}

-- Get or initialize data for a buffer
local function get_buffer_data(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not buffer_data[bufnr] then
    buffer_data[bufnr] = {
      word_freq = {},
      bigram_freq = {},
      last_tick = 0
    }
  end
  
  return buffer_data[bufnr]
end

-- Extract words from text (3+ alphabetic characters)
local function extract_words(text)
  local words = {}
  
  -- Match words with 3+ alphabetic characters
  for word in text:gmatch('%a%a%a+') do
    table.insert(words, word:lower())
  end
  
  return words
end

-- Update frequency models for current buffer
function M.update_frequencies(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Check if buffer exists and is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  local data = get_buffer_data(bufnr)
  local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
  
  -- Skip if nothing changed
  if data.last_tick == current_tick then
    return
  end
  
  -- Get all lines from buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, ' ')
  
  -- Clear existing frequencies
  data.word_freq = {}
  data.bigram_freq = {}
  
  -- Extract words
  local words = extract_words(text)
  
  -- Build unigram frequencies
  for _, word in ipairs(words) do
    data.word_freq[word] = (data.word_freq[word] or 0) + 1
  end
  
  -- Build bigram frequencies
  for i = 1, #words - 1 do
    local bigram = words[i] .. '|' .. words[i + 1]
    data.bigram_freq[bigram] = (data.bigram_freq[bigram] or 0) + 1
  end
  
  data.last_tick = current_tick
end

-- Get frequency of a word (unigram)
function M.get_word_frequency(word, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = get_buffer_data(bufnr)
  local word_lower = word:lower()
  
  return data.word_freq[word_lower] or 0
end

-- Get frequency of a word pair (bigram)
function M.get_bigram_frequency(word1, word2, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = get_buffer_data(bufnr)
  local bigram = word1:lower() .. '|' .. word2:lower()
  
  return data.bigram_freq[bigram] or 0
end

-- Get all words matching a prefix
function M.get_words_with_prefix(prefix, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = get_buffer_data(bufnr)
  local prefix_lower = prefix:lower()
  local prefix_len = #prefix_lower
  local matches = {}
  
  for word, freq in pairs(data.word_freq) do
    if #word > prefix_len and word:sub(1, prefix_len) == prefix_lower then
      matches[word] = freq
    end
  end
  
  return matches
end

-- Get all bigrams where first word matches and second word starts with prefix
function M.get_bigrams_with_prefix(first_word, prefix, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = get_buffer_data(bufnr)
  local first_lower = first_word:lower()
  local prefix_lower = prefix:lower()
  local prefix_len = #prefix_lower
  local matches = {}
  
  local search_pattern = first_lower .. '|'
  
  for bigram, freq in pairs(data.bigram_freq) do
    if bigram:sub(1, #search_pattern) == search_pattern then
      local second_word = bigram:sub(#search_pattern + 1)
      if #second_word > prefix_len and second_word:sub(1, prefix_len) == prefix_lower then
        matches[second_word] = freq
      end
    end
  end
  
  return matches
end

-- Clear frequency data for a buffer
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  buffer_data[bufnr] = nil
end

-- Get statistics about the frequency model
function M.get_stats(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = get_buffer_data(bufnr)
  
  local unique_words = 0
  for _ in pairs(data.word_freq) do
    unique_words = unique_words + 1
  end
  
  local unique_bigrams = 0
  for _ in pairs(data.bigram_freq) do
    unique_bigrams = unique_bigrams + 1
  end
  
  return {
    unique_words = unique_words,
    unique_bigrams = unique_bigrams,
    last_tick = data.last_tick
  }
end

-- Clean up data for buffers that no longer exist
function M.cleanup_deleted_buffers()
  for bufnr in pairs(buffer_data) do
    if not vim.api.nvim_buf_is_valid(bufnr) then
      buffer_data[bufnr] = nil
    end
  end
end

return M
