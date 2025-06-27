if vim.fn.has 'nvim-0.11' == 0 then
	return
end

local bufnr = vim.api.nvim_get_current_buf()

local function get_root_if_gitcommit()
	if vim.bo.filetype ~= 'gitcommit' or not vim.fn.expand '%:p':match '/%.git/COMMIT_EDITMSG$' then
		return nil
	end
	local projroot = vim.fn.expand '%:p:h:h'
	if vim.fn.isdirectory(projroot .. '/.git') == 0 then
		return nil
	end
	return projroot
end

local root = get_root_if_gitcommit()
if root and not vim.b.commitgen_result then
	vim.notify('Requesting commit message for ' .. root, vim.log.levels.INFO)
	vim.fn['commitgen#get_async'](root, function(v)
		vim.notify('Commit message reseived', vim.log.levels.INFO)
		vim.api.nvim_buf_set_var(bufnr, 'commitgen_result', v)
	end, function(e)
		vim.notify('Error: ' .. e, vim.log.levels.ERROR)
	end)

	vim.keymap.set('n', '<Plug>(commitgen-select)', function()
		if not vim.b.commitgen_result then
			vim.notify('No commit message available yet.', vim.log.levels.WARN)
		else
			vim.ui.select(vim.b.commitgen_result, {
				prompt = 'Select commit message:',
				format_item = function(item)
					return item.conventionalCommitType .. ': ' .. item.commitMsgContent
				end,
			}, function(item)
				if item then
					local msg = item.conventionalCommitType .. ': ' .. item.commitMsgContent
					vim.api.nvim_put({ msg }, 'c', true, true)
				else
					vim.notify('No commit message selected.', vim.log.levels.WARN)
				end
			end)
		end
	end, { desc = 'Commitgen: Generate commit message' })
end
