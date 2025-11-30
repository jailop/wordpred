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
  extmark_id = -1
}

-- Show prediction at current cursor position
function M.show(prediction_text)
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
  
  -- Clear any existing prediction
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  -- Get highlight group
  local hl_group = vim.g.wordpred_hl_group or 'Comment'
  
  -- Set extmark with virtual text
  local opts = {
    virt_text = {{prediction_text, hl_group}},
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
    extmark_id = -1
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
  -- Get prediction from predict module
  local prediction = predict.get_current_prediction()
  
  if prediction ~= '' then
    M.show(prediction)
  else
    M.hide()
  end
end

return M
