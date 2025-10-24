-- Fix for Tree-sitter "Invalid 'end_col': out of range" error
-- This wraps nvim_buf_set_extmark to catch and suppress the error

local original_set_extmark = vim.api.nvim_buf_set_extmark

vim.api.nvim_buf_set_extmark = function(buffer, ns_id, line, col, opts)
  local ok, result = pcall(original_set_extmark, buffer, ns_id, line, col, opts)

  if ok then
    return result
  else
    -- Suppress the specific "Invalid 'end_col'" error
    local err_msg = tostring(result)
    if err_msg:match("Invalid 'end_col'") then
      -- Silently skip this highlight, or log at debug level
      -- Return a dummy extmark ID
      return 1
    else
      -- Re-raise other errors
      error(result)
    end
  end
end
