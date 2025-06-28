function commitgen#utils#buf_is_gitcommit() abort
	return commitgen#utils#is_gitcommit() && &ft == 'gitcommit'
endfunction

function commitgen#utils#is_gitcommit(path = expand('%')) abort
	try
		let validpath = fnamemodify(a:path, ':p')
	catch /.*/
		throw 'Invalid path: ' . a:path
	endtry
	return validpath =~ '/\.git/COMMIT_EDITMSG$' && isdirectory(fnamemodify(validpath, ':h'))
endfunction

function commitgen#utils#get_git_root(path = expand('%')) abort
	try
		let validpath = fnamemodify(a:path, ':p')
	catch /.*/
		throw 'Invalid path: ' . a:path
	endtry

	if commitgen#utils#is_gitcommit(validpath)
		let projroot = fnamemodify(validpath, ':h:h')
		if !isdirectory(projroot .. '/.git')
			return v:null
		endif
		return projroot
	endif

	if has('nvim')
		let dotgit = luaeval('vim.fs.find(".git", { upward = true, path = _A[1] })[1]', [validpath])
		return dotgit != v:null ? fnamemodify(dotgit, ':p:h:h') : v:null
	else
		let fsize = getfsize(validpath)
		if fsize == -1
			" If the file does not exist, we assume it's a not-created-yet file in a directory.
			let validpath = fnamemodify(validpath, ':p:h')
			let fsize = getfsize(validpath)
		endif
		if fsize == 0
			" Directory
		elseif fsize == -2 || fsize > 0
			" File
			let validpath = fnamemodify(validpath, ':p:h')
		else
			" Invalid path
			throw 'Invalid path: ' . validpath
		endif
		let projroot = system('cd ' . shellescape(validpath) . ' && git rev-parse --show-toplevel')
		if projroot =~ '\n$'
			let projroot = projroot[:-2]
		endif
		return v:shell_error ? v:null : projroot == '' ? v:null : projroot
	endif
endfunction
