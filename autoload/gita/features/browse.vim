let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#import('Data.List')
let s:F = gita#import('System.File')
let s:A = gita#import('ArgumentParser')


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
      \ '--scheme',
      \ 'Which scheme to determine remote URL.', {
      \   'type': s:A.types.value,
      \   'default': '_',
      \ })
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit which you want to compare with.',
      \   'If nothing is specified, it will ask which commit you want to compare.',
      \   'If <commit> is specified, it show changes in working tree relative to the named <commit>.',
      \   'If <commit>..<commit> is specified, it show the changes between two arbitrary <commit>.',
      \   'If <commit>...<commit> is specified, it show thechanges on the branch containing and up ',
      \   'to the second <commit>, starting at a common ancestor of both <commit>.',
      \ ], {
      \   'complete': function('gita#features#diff#_complete_commit'),
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
function! s:normalize_commit(gita, commit) abort " {{{
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[ 1 : 2 ]
    " find a common ancestor by merge-base
    let result = a:gita.operations.merge_base({
          \ 'commit1': lhs,
          \ 'commit2': rhs,
          \}, {
          \ 'echo': 'fail',
          \})
    if result.status
      return ['', '', '']
    endif
    return s:normalize_commit(a:gita, result.stdout)
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let lhs = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[1]
    " use lhs
    return s:normalize_commit(a:gita, lhs)
  elseif empty(a:commit)
    " current local branch
    let meta = a:gita.git.get_meta()
    let commit = meta.local.branch_name
  else
    let commit = a:commit
  endif
  " find remote branch
  let branch_merge = a:gita.git.get_branch_merge(commit)
  if empty(branch_merge)
    " no remote branch is found. the commit may be sha256 or local branch
    " so use 'origin' to figur out url
    let remote = 'origin'
  else
    let commit = substitute(branch_merge, '\C^refs/heads/', '', '')
    let remote = a:gita.git.get_branch_remote(commit)
  endif
  let remote_url = a:gita.git.get_remote_url(remote)
  return [remote, commit, remote_url]
endfunction " }}}
function! s:find_url(gita, expr, options) abort " {{{
  let commit  = get(a:options, 'commit', gita#meta#get('commit', ''))
  let abspath = gita#utils#ensure_abspath(gita#utils#expand(a:expr))
  let relpath = a:gita.git.get_relative_path(abspath)

  " get selected region
  if abspath != gita#utils#ensure_abspath(gita#utils#expand('%'))
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

  " normalize commit to figure out remote, commit, and remote_url
  let [remote, commit, remote_url] = s:normalize_commit(gita#get(), commit)
  let revision = a:gita.git.get_remote_hash(remote, commit)

  " create a URL
  let data = {
        \ 'path':       gita#utils#ensure_unixpath(relpath),
        \ 'commit':     commit,
        \ 'revision':   revision,
        \ 'remote':     remote,
        \ 'remote_url': remote_url,
        \ 'line_start': line_start,
        \ 'line_end':   line_end,
        \}
  let format_map = {
        \ 'path':     'path',
        \ 'commit':   'commit',
        \ 'revision': 'revision',
        \ 'remote':   'remote',
        \ 'ls':       'line_start',
        \ 'le':       'line_end',
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
    " s:find_url require a REAL path to find relative path
    let options['--'] = gita#utils#ensure_realpathlist(options['--'])
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
  if !empty(options)
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
  endif
endfunction " }}}
function! gita#features#browse#complete(arglead, cmdline, cursorpos) abort " {{{
  let candidates = s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}
function! gita#features#browse#translate_url(url, translation_patterns, ...) abort " {{{
  let options = get(a:000, 0, {})
  for [domain, info] in items(a:translation_patterns)
    for pattern in info[0]
      let pattern = substitute(pattern, '\C' . '%domain', domain, 'g')
      if a:url =~# pattern
        let scheme = get(info[1], get(options, 'scheme', '_'), info[1]['_'])
        " Prefer second pattern if 'exact' is specified. Use first pattern if
        " no second pattern exists
        let repl = substitute(a:url, '\C' . pattern, scheme, 'g')
        return repl
      endif
    endfor
  endfor
  return ''
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
