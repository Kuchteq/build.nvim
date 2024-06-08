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
local get_longest_name = function(list)
        local longest = 0;
        for _, v in ipairs(list) do
                longest = math.max(longest, string.len(v))
        end
        return longest
end

local selected_target_name = ""
local target_select_buf = nil;
local target_select_win_id

local render_targets = function(dest_buf)
        local output = vim.fn.system("make --print-targets")
        local targets_list = vim.split(output, "\n")
        table.remove(targets_list, #targets_list)
        for i, v in ipairs(targets_list) do
                if v == selected_target_name then
                        targets_list[i] = "> " .. v
                end
        end
        vim.api.nvim_buf_set_lines(dest_buf, 0, -1, false, targets_list);
        return targets_list;
end

local write_target = function(target)
        local default_path = os.getenv("XDG_RUNTIME_DIR") .. "/makeshelltarget";
        local file = io.open(default_path, "w") -- Open the file in append mode
        if file then
                file:write(target, "\n")        -- Using ASCII value for '|'
                file:close()
        end
end
local function select_target()
        if target_select_win_id ~= nil then
                return
        end
        if target_select_buf == nil then
                target_select_buf = vim.api.nvim_create_buf(false, true);
                vim.api.nvim_create_autocmd({ "WinClosed" }, {
                        callback = function()
                                if target_select_win_id then
                                        vim.api.nvim_win_close(target_select_win_id, true)
                                        target_select_win_id = nil
                                end
                        end,
                        buffer = target_select_buf
                })
                vim.keymap.set("n", "<esc>", function()
                        if target_select_win_id then
                                vim.api.nvim_win_close(target_select_win_id, true);
                        end
                end, { buffer = target_select_buf })
                vim.keymap.set("n", "<enter>", function()
                        selected_target_name = vim.api.nvim_get_current_line();
                        write_target(selected_target_name);
                        render_targets(target_select_buf);
                end, { buffer = target_select_buf })
        end

        local targets_list = render_targets(target_select_buf)
        local win_len = math.max(get_longest_name(targets_list), string.len(" Make targets "))
        target_select_win_id = vim.api.nvim_open_win(target_select_buf, true, {
                relative = "editor",
                col = math.floor((vim.o.columns - win_len) / 2),
                row = math.floor((vim.o.lines - #targets_list) / 2),
                width = win_len,
                height = #targets_list,
                border = "rounded",
                style = "minimal",
                title = "Make targets",
                title_pos = "center"
        });
end

vim.keymap.set("n", "<leader>t", function()
        select_target();
end)

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
                local command = "foot -o 'text-bindings.\\x03 TRAPUSR2\\x0d=0xffbf' " .. module_dir .. "/makeshell '" .. vim.fn.expand("%:p") .. "'"

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
                self.win_id = vim.api.nvim_open_win(self.buf_id, true, vim.tbl_extend("force", { title = "Error", title_pos = "center", relative = "editor", border = "rounded", style = "minimal" }, self.get_sizing()))
                vim.api.nvim_set_hl(0, 'FloatBorder', { fg = "#ff0000" })
                vim.api.nvim_set_hl(0, 'FloatTitle', { fg = "#ff0000", bold = true })
        end,
        toggle = function(self)
                if self.win_id then
                        vim.api.nvim_win_close(self.win_id, true)
                else
                        if not self.buf_id then
                                self:init()
                        end
                        self.win_id = vim.api.nvim_open_win(self.buf_id, true, vim.tbl_extend("force", { relative = "editor", border = "rounded", style = "minimal" }, self.get_sizing()))
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
                        write_target(self.default_target);
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
                        -- Kill the child processes first so that the trap doesn't just get ignored
                        local killjob = vim.fn.jobstart("kill $(ps -s " .. self.buf_id .. " -o pid=)")
                        vim.fn.jobwait({ killjob }, 3000)
                        vim.fn.jobstart("kill -s USR2 " .. self.buf_id)
                        return
                end
                local cmd = vim.api.nvim_exec2("!make " .. selected_target_name .. " CFLAGS=-fdiagnostics-color=always", { output = true });
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
        local targets_filename = vim.fn.stdpath('data') .. "/makeshelltargets"
        local file = io.open(targets_filename, "r")
        if file then
                io.close(file)
        else
                file = io.open(targets_filename, "w")
                if file then
                        io.close(file)
                else
                end
        end
end

local run_make = function() make_output:run_make() end;
return { setup = setup, run_make = run_make };
