function s:create_options(path) abort
	let projroot = commitgen#utils#get_git_root(a:path)
	if projroot is v:null
		throw a:path . ' is not in a git repository.'
	endif
	let model = get(g:, 'commitgen_model', 'gpt-4o')
	let count = get(g:, 'commitgen_count', 5)
	let api_key = get(g:, 'commitgen_api_key', v:null)
	let base_url = get(g:, 'commitgen_base_url', v:null)
	return [model, projroot, count, api_key, base_url]
endfunction

function commitgen#get(path) abort
	if denops#plugin#wait('commitgen') != 0
		throw 'commitgen plugin is not ready.'
	endif

	return denops#request(
		\   'commitgen',
		\   'commitgen',
		\   s:create_options(a:path),
		\ )
endfunction

function s:err_tostring(err) abort
	if get(a:err, 'proto', v:null) == 'Error' && has_key(a:err, 'message') && type(a:err.message) == v:t_string
		return a:err.message
	elseif type(a:err) == v:t_string
		return a:err
	else
		return json_encode(a:err)
	endif
endfunction

function commitgen#get_async(path, success, failure = { e -> execute('throw string(a:e)') }) abort
	call denops#request_async(
		\   'commitgen',
		\   'commitgen',
		\   s:create_options(a:path),
		\   type(a:success) == v:t_func ? { v -> call(a:success, [v]) } : { _ -> v:null },
		\   type(a:failure) == v:t_func ? { e -> call(a:failure, [s:err_tostring(e)]) } : { _ -> v:null },
		\ )
endfunction

" Called from Deno side via denops.call("commitgen#progress", event)
" On Neovim, delegates to Lua for floating window progress UI.
" On Vim, echoes progress to the message area.
function commitgen#progress(event) abort
	if has('nvim')
		call luaeval('require("commitgen")._on_progress(_A)', a:event)
	else
		let l:type = a:event['type']
		if l:type ==# 'info'
			echomsg printf('[commitgen] %s (%d bytes)',
				\ a:event.strategy ==# 'inline'
				\   ? 'Analyzing diff'
				\   : printf('Map-Reduce: %d chunks', a:event.chunkCount),
				\ a:event.diffBytes)
		elseif l:type ==# 'map_progress'
			echomsg printf('[commitgen] Summarizing chunk %d/%d',
				\ a:event.current, a:event.total)
		elseif l:type ==# 'reduce_start'
			echomsg '[commitgen] Generating commit messages...'
		endif
	endif
	return v:null
endfunction
