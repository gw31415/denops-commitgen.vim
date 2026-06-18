if vim.fn.has 'nvim-0.11' == 0 then
	return {}
end

local M = {}

-- ── Cache ────────────────────────────────────────────────────────────────
-- { [root] = { hash = string, body = CommitMessage[] } }
local commitmsg_db = {}

-- ── Progress floating window ──────────────────────────────────────────────

local prog = { buf = nil, win = nil }

local function prog_close()
	if prog.win and vim.api.nvim_win_is_valid(prog.win) then
		vim.api.nvim_win_close(prog.win, true)
	end
	if prog.buf and vim.api.nvim_buf_is_valid(prog.buf) then
		vim.api.nvim_buf_delete(prog.buf, { force = true })
	end
	prog.win = nil
	prog.buf = nil
end

local function prog_open(lines)
	prog_close()
	local width = 34 -- minimum width to fit progress bar updates
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	prog.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(prog.buf, 0, -1, false, lines)
	prog.win = vim.api.nvim_open_win(prog.buf, false, {
		relative = 'editor',
		anchor = 'SE',
		row = vim.o.lines - 2,
		col = vim.o.columns - 1,
		width = width,
		height = #lines,
		style = 'minimal',
		border = 'rounded',
		title = ' commitgen ',
		title_pos = 'center',
		zindex = 200,
	})
	vim.cmd 'redraw'
end

local function prog_set_line(idx, text)
	if prog.buf and vim.api.nvim_buf_is_valid(prog.buf) then
		vim.api.nvim_buf_set_lines(prog.buf, idx, idx + 1, false, { text })
		vim.cmd 'redraw'
	end
end

local function make_bar(current, total, len)
	local filled = math.floor(len * current / total + 0.5)
	filled = math.max(0, math.min(filled, len))
	return string.rep('█', filled) .. string.rep('░', len - filled)
end

--- Called from VimL via luaeval when denops.call("commitgen#progress", event) fires.
--- Manages a floating window progress indicator.
function M._on_progress(event)
	if event.type == 'info' then
		if event.strategy == 'map-reduce' then
			prog_open {
				string.format(' Map-Reduce: %d chunks (%.1f KB)', event.chunkCount, event.diffBytes / 1024),
				string.format(' %s %d/%d', make_bar(0, event.chunkCount, 20), 0, event.chunkCount),
			}
		else
			prog_open { string.format(' Analyzing diff (%.1f KB)...', event.diffBytes / 1024) }
		end
	elseif event.type == 'map_progress' then
		prog_set_line(1, string.format(' %s %d/%d', make_bar(event.current, event.total, 20), event.current, event.total))
	elseif event.type == 'reduce_start' then
		prog_set_line(1, ' Synthesizing commit messages...')
	end
	-- 'result' events are not forwarded; closing is handled by the caller
end

-- ── Helpers ──────────────────────────────────────────────────────────────

local function get_git_info()
	local root = vim.fn['commitgen#utils#get_git_root']()
	if root == vim.NIL then
		return nil, nil
	end
	local hash = vim.fn['commitgen#utils#get_current_hash']()
	return root, hash
end

local function select_and_paste(body, after)
	vim.ui.select(body, {
		prompt = 'Select commit message:',
		format_item = function(item)
			return vim.fn.printf('%-10S%s', item.conventionalCommitType .. ':', item.commitMsgContent)
		end,
	}, function(item)
		if item then
			local msg = item.conventionalCommitType .. ': ' .. item.commitMsgContent
			vim.api.nvim_put({ msg }, 'c', after, true)
		else
			vim.notify('No commit message selected.', vim.log.levels.WARN)
		end
	end)
end

local function fetch_async(root, hash, on_success, on_error)
	vim.fn['commitgen#get_async'](root, function(v)
		prog_close()
		commitmsg_db[root] = { hash = hash, body = v }
		if on_success then
			on_success(v)
		end
	end, function(err)
		prog_close()
		if on_error then
			on_error(err)
		else
			vim.notify('commitgen error: ' .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

-- ── Public API ───────────────────────────────────────────────────────────

--- Generate (or reuse cached) commit messages, then prompt the user to select one.
--- Uses async fetching with a floating window progress indicator.
M.paste = function(opts)
	local opts_inner = vim.tbl_deep_extend('keep', opts or {}, {
		after = true,
		renew = false,
	})
	local root, hash = get_git_info()
	if not root then
		return
	end

	-- Use cached result if available
	if
		not opts_inner.renew
		and commitmsg_db[root]
		and commitmsg_db[root].hash == hash
	then
		select_and_paste(commitmsg_db[root].body, opts_inner.after)
		return
	end

	-- Async fetch with progress UI, then select
	fetch_async(root, hash, function(v)
		select_and_paste(v, opts_inner.after)
	end)
end

--- Pre-fetch commit messages in the background.
--- Shows a floating window progress indicator.
M.request = function(opts)
	local opts_inner = vim.tbl_deep_extend('keep', opts or {}, {
		renew = false,
	})
	local root, hash = get_git_info()
	if not root then
		return
	end

	if
		not opts_inner.renew
		and commitmsg_db[root]
		and commitmsg_db[root].hash == hash
	then
		return
	end

	fetch_async(root, hash, function(v)
		vim.notify('commitgen: ready (' .. #v .. ' candidates)', vim.log.levels.INFO)
	end)
end

return M
