function s:create_options(path) abort
	if has('nvim')
		let dotgit = luaeval('vim.fs.find(".git", { upward = true, path = _A[1] })[1]', [a:path])
		let projroot = dotgit != v:null ? fnamemodify(dotgit, ':p:h:h') : v:null
	else
		let path = a:path
		let fsize = getfsize(path)
		if fsize == -1
			" If the file does not exist, we assume it's a not-created-yet file in a directory.
			let path = fnamemodify(path, ':p:h')
			let fsize = getfsize(path)
		endif
		if fsize == 0
			" Directory
		elseif fsize == -2 || fsize > 0
			" File
			let path = fnamemodify(path, ':p:h')
		else
			" Invalid path
			throw 'Invalid path: ' . path
		endif
		let projroot = system('cd ' . shellescape(path) . ' && git rev-parse --show-toplevel')
		if projroot =~ '\n$'
			let projroot = projroot[:-2]
		endif
		if v:shell_error
			let projroot = v:null
		endif
	endif
	if type(projroot) != v:t_string || projroot == ''
		throw 'Not a git repository: ' . a:path
	endif
	let model = get(g:, 'commitgen_model', 'gpt-4o')
	let count = get(g:, 'commitgen_count', 5)
	return [model, projroot, count]
endfunction

function commitgen#get(path) abort
	return denops#request(
		  \ 'commitgen',
		  \ 'commitgen',
		  \ s:create_options(a:path),
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

function commitgen#get_async(path, success, failure = v:null) abort
	call denops#request_async(
		  \ 'commitgen',
		  \ 'commitgen',
		  \ s:create_options(a:path),
		  \ type(a:success) == v:t_func ? { v -> call(a:success, [v]) } : { _ -> v:null },
		  \ type(a:failure) == v:t_func ? { e -> call(a:failure, [s:err_tostring(e)]) } : { _ -> v:null },
		  \ )
endfunction
