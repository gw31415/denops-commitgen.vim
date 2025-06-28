if vim.fn.has 'nvim-0.11' == 0 then
	return {}
end

-- TODO: the commitmsg_db will become bloated
local commitmsg_db = {}

return {
	paste = function(opts)
		local opts_inner = vim.tbl_deep_extend('keep', opts or {}, {
			after = true,
			renew = false,
		})
		local root = vim.fn['commitgen#utils#get_git_root']()
		if root == vim.NIL then
			return
		end
		local hash = vim.fn['commitgen#utils#get_current_hash']()

		if opts_inner.renew or commitmsg_db[hash] == nil then
			vim.cmd("echo " .. vim.fn.string('Requesting commit message for ' .. root) .. " | redraw")
			commitmsg_db[hash] = vim.fn['commitgen#get'](root)
		end

		vim.ui.select(commitmsg_db[hash], {
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
		local root = vim.fn['commitgen#utils#get_git_root']()
		if root == vim.NIL then
			return
		end
		local hash = vim.fn['commitgen#utils#get_current_hash']()

		if not opts_inner.renew and commitmsg_db[hash] ~= nil then
			-- Skip
			return
		end


		vim.notify('Requesting commit message for ' .. root, vim.log.levels.INFO)
		vim.fn['commitgen#get_async'](root, function(v)
			commitmsg_db[hash] = v
		end)
	end
}
