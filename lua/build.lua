local last_warning_time
local where = "external_term"

local statusLineExtension = {
        function()
                if vim.loop.now() - last_warning_time < 2000 then
                        return "Made with warnings"
                end
                return ""
        end,
        color = { fg = "#C47FD5" }
}
local make_output = {
        win_id = nil,
        buf_id = nil,
        init = function(self)
                if where == "external_term" then
                        self:init_termwin()
                        return
                end
                self.buf_id = api.nvim_create_buf(false, true)
                vim.keymap.set("n", "<ESC>", function()
                        api.nvim_win_close(self.win_id, true)
                end, { buffer = self.buf_id })
                api.nvim_create_autocmd({ "WinClosed" }, {
                        callback = function()
                                self.win_id = nil;
                        end,
                        buffer = self.buf_id
                })
                api.nvim_create_autocmd({ "BufDelete" }, {
                        callback = function()
                                self.win_id = nil;
                                self.buf_id = nil
                        end,
                        buffer = self.buf_id
                })
                local existing = require('lualine').get_config().sections.lualine_c
                for _, value in pairs(existing) do
                        if value == statusLineExtension then
                                return
                        end
                end
                table.insert(existing, statusLineExtension)

                require('lualine').setup({ sections = { lualine_c = existing } })
        end,
        external_shell_sync_job = nil,
        init_termwin = function(self)
                local module_dir = debug.getinfo(1).source:sub(2):gsub("/[^/]+$", "")
                local command = "foot " .. module_dir .. "/makeshell"

                self.external_shell_sync_job = vim.fn.jobstart("[ ! -f $XDG_RUNTIME_DIR/makeshell ] && mkfifo $XDG_RUNTIME_DIR/makeshell; cat $XDG_RUNTIME_DIR/makeshell", {
                        on_stdout = function(_, data, _)
                                if data[1] ~= "" then
                                        self.buf_id = data[1];
                                end
                        end,
                })
                vim.fn.jobstart(command, {
                        on_exit = function(_, exit_code, _)
                                print("Make terminal closed" .. exit_code)
                                self.buf_id = nil
                        end,
                })
        end,
        get_sizing = function()
                local nvim_width = vim.go.columns;
                local nvim_height = vim.go.lines;
                local lf_width = math.floor(nvim_width * 0.8)
                local lf_height = math.floor(nvim_height * 0.8)
                return {
                        col = math.floor((nvim_width - lf_width) / 2),
                        row = math.floor((nvim_height - lf_height) / 2 - 2),
                        width = lf_width,
                        height = lf_height
                }
        end,
        open_error_win = function(self)
                if self.win_id then
                        return
                end
                self.win_id = api.nvim_open_win(self.buf_id, true, vim.tbl_extend("force", { title = "Error", title_pos = "center", relative = "editor", border = "rounded", style = "minimal" }, self.get_sizing()))
                vim.api.nvim_set_hl(0, 'FloatBorder', { fg = "#ff0000" })
                vim.api.nvim_set_hl(0, 'FloatTitle', { fg = "#ff0000", bold = true })
        end,
        toggle = function(self)
                if self.win_id then
                        api.nvim_win_close(self.win_id, true)
                else
                        if not self.buf_id then
                                self:init()
                        end
                        self.win_id = api.nvim_open_win(self.buf_id, true, vim.tbl_extend("force", { relative = "editor", border = "rounded", style = "minimal" }, self.get_sizing()))
                end
        end,
        default_target = nil,
        get_default_target = function(self)
                local entries = {}
                for line in io.lines(vim.fn.stdpath('data') .. "/makeshelltargets") do
                        local path, value = line:match("([^%s]+)%s*—%s*([^%s]+)")
                        if path and value then
                                entries[path] = value
                        end
                end
                self.default_target = entries[vim.fn.getcwd()]
                if self.default_target then
                        local default_path = os.getenv("XDG_RUNTIME_DIR") .. "/makeshelltarget";
                        local file = io.open(default_path, "w") -- Open the file in append mode
                        if file then
                                file:write(self.default_target, "\n") -- Using ASCII value for '|'
                                file:close()
                        end
                end
        end,
        run_make = function(self)
                self:get_default_target()
                vim.cmd('silent update')
                if not self.buf_id then
                        self:init()
                end
                if where == "external_term" then
                        vim.fn.jobwait({ self.external_shell_sync_job }, 3000)
                        vim.fn.jobstart("kill -s USR2 " .. self.buf_id)
                        return
                end
                local cmd = api.nvim_exec2("!make " .. target .. " CFLAGS=-fdiagnostics-color=always", { output = true });
                -- local cmd = api.nvim_exec2("!ls", { output = true });
                if string.find(cmd.output, "error: ") then
                        --This is not correct and not exact, TODO fix it but I am tired now
                        self:open_error_win();
                end

                cmd.output = string.gsub(cmd.output, "%^%[%[m%^%[%[K", "\x1b[0m")
                cmd.output = string.gsub(cmd.output, "%^%[%[K", "")
                cmd.output = string.gsub(cmd.output, "%^%[", "\x1b")
                local output = {}
                for line in cmd.output:gmatch("[^\n]+") do
                        table.insert(output, line)
                end
                local baleia = require('baleia').setup {}
                baleia.buf_set_lines(self.buf_id, 0, -1, false, output);

                if string.find(cmd.output, "warning: ") then
                        last_warning_time = vim.loop.now()
                end
        end


}

local function setup()
        vim.keymap.set({ "n" }, "<leader>m", function() make_output:run_make() end, { noremap = true, silent = true })
        vim.keymap.set({ "n" }, "<leader>M", function() make_output:toggle() end, { noremap = true, silent = true })
        vim.keymap.set({ "n" }, "<leader>M", function() make_output:toggle() end, { noremap = true, silent = true })
end

return { setup = setup };
