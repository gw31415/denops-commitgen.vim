function s:create_options(path) abort
	let projroot = commitgen#utils#get_git_root(a:path)
	if projroot is v:null
		throw a:path . ' is not in a git repository.'
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
		  \ type(a:failure) == v:t_func ? { e -> call(a:failure, [s:err_tostring(e)]) } : { e -> execute('throw string(' .. string(s:err_tostring(e)) .. ')') },
		  \ )
endfunction
