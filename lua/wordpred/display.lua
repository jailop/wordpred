-- display.lua - Display management for word predictions (Neovim)
-- Handles showing and hiding predictions as virtual text

local M = {}
local predict = require('wordpred.predict')

-- Namespace for virtual text
local ns_id = vim.api.nvim_create_namespace('wordpred')

-- Store current prediction state
local current_prediction = {
  text = '',
  bufnr = -1,
  line = -1,
  col = -1,
  extmark_id = -1,
  candidates = {},
  current_index = 0,
  source = 'none'
}

-- Get highlight group based on prediction source
local function get_highlight_group(source)
  if source == 'bigram' then
    return vim.g.wordpred_hl_group_bigram or vim.g.wordpred_hl_group or 'Comment'
  else
    return vim.g.wordpred_hl_group_unigram or vim.g.wordpred_hl_group or 'Comment'
  end
end

-- Show prediction at current cursor position
function M.show(prediction_text, source)
  source = source or 'unknown'
  
  if prediction_text == '' then
    M.hide()
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = pos[1] - 1  -- 0-indexed
  local col = pos[2]
  
  -- Store prediction state
  current_prediction.text = prediction_text
  current_prediction.bufnr = bufnr
  current_prediction.line = line
  current_prediction.col = col
  current_prediction.source = source
  
  -- Clear any existing prediction
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  -- Get highlight group
  local hl_group = get_highlight_group(source)
  
  -- Add source indicator if enabled
  local display_text = prediction_text
  if vim.g.wordpred_show_source == 1 then
    local indicator = source == 'bigram' and '⚡' or '●'
    display_text = prediction_text .. ' ' .. indicator
  end
  
  -- Set extmark with virtual text
  local opts = {
    virt_text = {{display_text, hl_group}},
    virt_text_pos = 'overlay',
    hl_mode = 'combine'
  }
  
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, opts)
  current_prediction.extmark_id = extmark_id
end

-- Hide current prediction
function M.hide()
  if current_prediction.bufnr == -1 then
    return
  end
  
  -- Clear namespace
  pcall(vim.api.nvim_buf_clear_namespace, current_prediction.bufnr, ns_id, 0, -1)
  
  -- Reset state
  current_prediction = {
    text = '',
    bufnr = -1,
    line = -1,
    col = -1,
    extmark_id = -1,
    candidates = {},
    current_index = 0,
    source = 'none'
  }
end

-- Accept current prediction (insert the text)
function M.accept()
  if current_prediction.text == '' then
    return false
  end
  
  -- Insert the prediction text
  local text = current_prediction.text
  M.hide()
  
  -- Insert the text at cursor
  local keys = vim.api.nvim_replace_termcodes(text, true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
  
  return true
end

-- Get current prediction text
function M.get_current()
  return current_prediction.text
end

-- Check if a prediction is currently shown
function M.is_shown()
  return current_prediction.text ~= ''
end

-- Update prediction (convenience function)
function M.update()
  local prefix = predict.get_current_word()
  local prev_word = predict.get_previous_word()
  
  if prefix == '' then
    M.hide()
    return
  end
  
  -- Get multiple candidates
  local candidates = predict.get_candidates(prefix, vim.api.nvim_get_current_buf(), prev_word)
  
  if vim.tbl_isempty(candidates) then
    M.hide()
    return
  end
  
  -- Store candidates and show first one
  current_prediction.candidates = candidates
  current_prediction.current_index = 0
  
  local prediction = candidates[1]
  local completion = prediction.word:sub(#prefix + 1)
  
  if completion ~= '' then
    M.show(completion, prediction.source)
  else
    M.hide()
  end
end

-- Cycle to next prediction candidate
function M.cycle_next()
  if vim.tbl_isempty(current_prediction.candidates) then
    return
  end
  
  current_prediction.current_index = 
    (current_prediction.current_index + 1) % #current_prediction.candidates
  
  -- Show current candidate
  local prefix = predict.get_current_word()
  local candidate = current_prediction.candidates[current_prediction.current_index + 1]
  local completion = candidate.word:sub(#prefix + 1)
  
  if completion ~= '' then
    M.show(completion, candidate.source)
  end
end

-- Cycle to previous prediction candidate
function M.cycle_prev()
  if vim.tbl_isempty(current_prediction.candidates) then
    return
  end
  
  current_prediction.current_index = 
    (current_prediction.current_index + #current_prediction.candidates - 1) 
    % #current_prediction.candidates
  
  -- Show current candidate
  local prefix = predict.get_current_word()
  local candidate = current_prediction.candidates[current_prediction.current_index + 1]
  local completion = candidate.word:sub(#prefix + 1)
  
  if completion ~= '' then
    M.show(completion, candidate.source)
  end
end

-- Get current candidate info (for display/debugging)
function M.get_candidates_info()
  if vim.tbl_isempty(current_prediction.candidates) then
    return 'No candidates'
  end
  
  local info = string.format('[%d/%d] ', 
    current_prediction.current_index + 1,
    #current_prediction.candidates)
  
  local candidate = current_prediction.candidates[current_prediction.current_index + 1]
  info = info .. string.format('%s (%s)', candidate.word, candidate.source)
  
  return info
end

return M
