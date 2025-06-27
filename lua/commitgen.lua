if vim.fn.has 'nvim-0.11' == 0 then
	return {}
end

local function is_buf_var_defined(bufnr, varname)
	local ok, _ = pcall(vim.api.nvim_buf_get_var, bufnr, varname)
	return ok
end

local function get_root()
	if vim.bo.filetype ~= 'gitcommit' or not vim.fn.expand '%:p':match '/%.git/COMMIT_EDITMSG$' then
		local dotgit = vim.fs.find('.git', { upward = true, path = vim.fn.expand '%:p' })[1]
		return dotgit and vim.fn.fnamemodify(dotgit, ':p:h:h') or nil
	end
	local projroot = vim.fn.expand '%:p:h:h'
	if vim.fn.isdirectory(projroot .. '/.git') == 0 then
		return nil
	end
	return projroot
end

return {
	paste = function(opts)
		local opts_inner = vim.tbl_deep_extend('keep', opts or {}, {
			after = true,
			renew = false,
		})
		local root = get_root()
		if not root then
			return
		end
		local bufnr = vim.api.nvim_get_current_buf()

		if opts_inner.renew or not is_buf_var_defined(bufnr, 'commitgen_result') then
			print('Requesting commit message for ' .. root)
			vim.api.nvim_buf_set_var(bufnr, 'commitgen_result', vim.fn['commitgen#get'](root))
		end

		vim.ui.select(vim.api.nvim_buf_get_var(bufnr, 'commitgen_result'), {
			prompt = 'Select commit message:',
			format_item = function(item)
				---@diagnostic disable-next-line: redundant-parameter
				return vim.fn.printf('%-10S%s', item.conventionalCommitType .. ':', item.commitMsgContent)
			end,
		}, function(item)
			if item then
				local msg = item.conventionalCommitType .. ': ' .. item.commitMsgContent
				vim.api.nvim_put({ msg }, 'c', opts_inner.after, true)
			else
				vim.notify('No commit message selected.', vim.log.levels.WARN)
			end
		end)
	end,

	request = function(opts)
		local opts_inner = vim.tbl_deep_extend('keep', opts or {}, {
			renew = false,
		})
		local root = get_root()
		if not root then
			return
		end
		local bufnr = vim.api.nvim_get_current_buf()

		if not opts_inner.renew and is_buf_var_defined(bufnr, 'commitgen_result') then
			-- Skip
			return
		end


		vim.notify('Requesting commit message for ' .. root, vim.log.levels.INFO)
		vim.fn['commitgen#get_async'](root, function(v)
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.notify('Commit message reseived', vim.log.levels.INFO)
				vim.api.nvim_buf_set_var(bufnr, 'commitgen_result', v)
			end
		end)
	end
}
