let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:F = gita#utils#import('System.File')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita[!] browse',
      \ 'description': 'Browse a selected region of the remote in a system default browser',
      \})
call s:parser.add_argument(
      \ '--open', '-o',
      \ 'Open a URL of a selected region of the remote in a system default browser (Default)', {
      \   'conflicts': ['yank', 'echo'],
      \ })
call s:parser.add_argument(
      \ '--yank', '-y',
      \ 'Yank a URL of a selected region of the remote.', {
      \   'conflicts': ['open', 'echo'],
      \ })
call s:parser.add_argument(
      \ '--echo', '-e',
      \ 'Echo a URL of a selected region of the remote.', {
      \   'conflicts': ['open', 'yank'],
      \ })
call s:parser.add_argument(
      \ '--exact',
      \ 'Use a git hash reference instead of a branch name to build a URL.', {
      \ })
call s:parser.add_argument(
      \ 'branch', [
      \   'A branch or commit which you want to see.',
      \   'If it is omitted, a remote branch of the current branch is used.'
      \ ], {
      \   'complete': function('gita#utils#completes#complete_local_branch'),
      \ })
function! s:parser.hooks.pre_validate(opts) abort " {{{
  " Automatically use '--open' if no conflicted argument is specified
  if empty(self.get_conflicted_arguments('open', a:opts))
    let a:opts.open = 1
  endif
endfunction " }}}
function! s:parser.hooks.post_complete_optional_argument(candidates, options) abort " {{{
  let candidates = s:L.flatten([
        \ gita#utils#completes#complete_staged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_unstaged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_conflicted_files('', '', [0, 0], a:options),
        \ a:candidates,
        \])
  return candidates
endfunction " }}}


function! s:yank_string(content) abort " {{{
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction " }}}
function! s:find_url(gita, expr, options) abort " {{{
  let path = gita#utils#expand(a:expr)
  let abspath = fnamemodify(path, ':p')
  let relpath = a:gita.git.get_relative_path(abspath)

  " get selected region
  if path != gita#utils#expand('%')
    let line_start = ''
    let line_end = ''
  elseif has_key(a:options, '__range__')
    let line_start = a:options.__range__[0]
    let line_end = a:options.__range__[1]
  elseif get(a:options, 'multiline', 0)
    let line_start = getpos("'<")[1]
    let line_end = getpos("'>")[1]
  else
    let line_start = getpos(".")[1]
    let line_end = ''
  endif
  let line_end = line_start == line_end ? '' : line_end

  " get local/remote branch info
  let meta = a:gita.git.get_meta()
  let local_branch = get(a:options, 'branch', '')
  let local_branch = empty(local_branch) ? meta.current_branch : local_branch
  let branch_merge = a:gita.git.get_branch_merge(local_branch)
  let remote_branch = substitute(branch_merge, '^refs/heads/', '', 'I')
  " use 'master' if no remote branch is found
  let branch = empty(remote_branch) ? 'master' : remote_branch
  let remote = a:gita.git.get_branch_remote(branch)
  let remote_url = a:gita.git.get_remote_url(remote)

  " use hashref instead of branch if 'exact' is specified
  if get(a:options, 'exact', 0)
    let branch = a:gita.git.get_remote_hash(remote, branch)
  endif

  " create a URL
  let data = {
        \ 'path': relpath,
        \ 'line_start': line_start,
        \ 'line_end': line_end,
        \ 'branch': branch,
        \ 'remote': remote,
        \ 'remote_url': remote_url,
        \ 'local_branch': local_branch,
        \ 'remote_branch': remote_branch,
        \}
  let format_map = {
        \ 'pt': 'path',
        \ 'ls': 'line_start',
        \ 'le': 'line_end',
        \ 'br': 'branch',
        \ 're': 'remote',
        \ 'lb': 'local_branch',
        \ 'rb': 'remote_branch',
        \}
  let translation_patterns = extend(
        \ deepcopy(g:gita#features#browse#translation_patterns),
        \ g:gita#features#browse#extra_translation_patterns,
        \)
  let url = gita#features#browse#translate_url(data.remote_url, translation_patterns, a:options)
  if !empty(url)
    return gita#utils#format_string(url, format_map, data)
  endif
  redraw
  call gita#utils#prompt#warn(printf(
        \ 'No url translation pattern for "%s" is found.',
        \ data.remote_url,
        \))
  if gita#utils#prompt#asktf('Do you want to open a help for adding extra translation patterns?')
    help g:gita#features#browse#extra_translation_patterns
  endif
  return ''
endfunction " }}}


function! gita#features#browse#exec(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = get(a:000, 0, {})
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  let urls = map(
        \ deepcopy(get(options, '--', [])),
        \ 's:find_url(gita, v:val, options)',
        \)
  return {
        \ 'status': 0,
        \ 'urls': urls,
        \}
endfunction " }}}
function! gita#features#browse#open(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let result = gita#features#browse#exec(options, config)
  if result.status != 0
    return
  endif
  redraw!
  for url in result.urls
    if !empty(url)
      call s:F.open(url)
      call gita#utils#prompt#echo(printf(
            \ '"%s" is opened.',
            \ url,
            \))
    endif
  endfor
endfunction " }}}
function! gita#features#browse#yank(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let result = gita#features#browse#exec(options, config)
  if result.status != 0
    return
  endif

  redraw!
  for url in result.urls
    if !empty(url)
      call s:yank_string(url)
      call gita#utils#prompt#echo(printf(
            \ '"%s" is yanked.',
            \ url,
            \))
    endif
  endfor
endfunction " }}}
function! gita#features#browse#echo(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let result = gita#features#browse#exec(options, config)
  if result.status != 0
    return
  endif

  redraw!
  for url in result.urls
    if !empty(url)
      call gita#utils#prompt#echo(url)
    endif
  endfor
endfunction " }}}
function! gita#features#browse#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  " automatically assign the current buffer if no file is specified
  let options['--'] = options.__unknown__
  if empty(get(options, '--', []))
    let options['--'] = ['%']
  endif
  let options = extend(
        \ deepcopy(g:gita#features#browse#default_options),
        \ options)
  if !empty(options)
    if get(options, 'open')
      call gita#features#browse#open(options)
    elseif get(options, 'yank')
      call gita#features#browse#yank(options)
    elseif get(options, 'echo')
      call gita#features#browse#echo(options)
    else
      call gita#utils#debugmsg(
            \ 'No available action is specified',
            \ 'options:', options,
            \)
    endif
  endif
endfunction " }}}
function! gita#features#browse#complete(arglead, cmdline, cursorpos) abort " {{{
  let candidates = s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}
function! gita#features#browse#translate_url(url, translation_patterns, ...) abort " {{{
  let options = get(a:000, 0, {})
  for pattern in a:translation_patterns
    if a:url =~# pattern[0]
      " Prefer second pattern if 'exact' is specified. Use first pattern if
      " no second pattern exists
      let repl = get(pattern, get(options, 'exact', 0) ? 2 : 1, pattern[1])
      let repl = substitute(a:url, pattern[0], repl, 'gI')
      return repl
    endif
  endfor
  return ''
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
