local winbar = require("dap-view.options.winbar")
local state = require("dap-view.state")
local globals = require("dap-view.globals")
local vendor = require("dap-view.breakpoints.vendor")
local extmarks = require("dap-view.exceptions.util.extmarks")
local treesitter = require("dap-view.exceptions.util.treesitter")

local api = vim.api

local M = {}


---@param row integer
---@param len_path integer
---@param len_lnum integer
local highlight_file_name_and_line_number = function(row, len_path, len_lnum)
    if state.bufnr then
        local lnum_start = len_path + 1

        api.nvim_buf_set_extmark(
            state.bufnr,
            globals.NAMESPACE,
            row,
            0,
            { end_col = len_path, hl_group = "qfFileName" }
        )

        api.nvim_buf_set_extmark(
            state.bufnr,
            globals.NAMESPACE,
            row,
            lnum_start,
            { end_col = lnum_start + len_lnum, hl_group = "qfLineNr" }
        )
    end
end

local populate_buf_with_breakpoints = function()
    if state.bufnr then
        -- Clear previous content
        api.nvim_buf_set_lines(state.bufnr, 0, -1, true, {})

        -- TODO: decide between getting breakpoints
        -- (A) by getting placed signs (nvim-dap approach)
        -- (B) by listing breakpoints via QuickFix list (might have some issues if using the qflist for something else)
        local breakpoints = vendor.get()

        local line_count = 0

        for buf, buf_entries in pairs(breakpoints) do
            local filename = api.nvim_buf_get_name(buf)
            local relative_path = vim.fn.fnamemodify(filename, ":.")

            for _, entry in pairs(buf_entries) do
                local line_content = {}

                local buf_lines = api.nvim_buf_get_lines(buf, entry.lnum - 1, entry.lnum, true)
                local text = table.concat(buf_lines, "\n")

                table.insert(line_content, relative_path .. "|" .. entry.lnum .. "|" .. text)

                api.nvim_buf_set_lines(state.bufnr, line_count, line_count, false, line_content)

                local col_offset = #relative_path + #tostring(entry.lnum) + 2

                treesitter.copy_highlights(buf, entry.lnum - 1, line_count, col_offset)
                extmarks.copy_extmarks(buf, entry.lnum - 1, line_count, col_offset)

                highlight_file_name_and_line_number(
                    line_count,
                    #relative_path,
                    #tostring(entry.lnum)
                )

                line_count = line_count + 1
            end
        end

        -- Remove the last line, as it's empty (for some reason)
        api.nvim_buf_set_lines(state.bufnr, -2, -1, false, {})
    end
end

M.show = function()
    winbar.update_winbar("breakpoints")

    populate_buf_with_breakpoints()
end

return M
