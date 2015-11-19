let s:save_cpoptions = &cpoptions
set cpoptions&vim

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
      \ '--branch', '-b',
      \ 'Force branch or commit used to retrieve url.', {
      \   'type': s:A.types.value,
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

function! s:find_remote_branch(gita, branch) abort " {{{
  let branch = a:branch =~# '^\%(INDEX\|WORKTREE\)$' ? 'HEAD' : a:branch
  let branch_merge = a:gita.git.get_branch_merge(branch)
  if empty(branch_merge)
    return branch
  endif
  return substitute(branch_merge, '\C^refs/heads/', '', '')
endfunction " }}}
function! s:find_common_ancestor(gita, commit1, commit2) abort " {{{
    " find a common ancestor by merge-base
    let result = a:gita.operations.merge_base({
          \ 'commit1': a:commit1,
          \ 'commit2': a:commit2,
          \}, {
          \ 'echo': 'fail',
          \})
    if result.status
      call gita#utils#prompt#debug(
            \ 'find_common_ancestor',
            \ a:commit1,
            \ a:commit2,
            \ result.status,
            \ result.stdout,
            \)
      return ''
    endif
    return result.stdout
endfunction " }}}
function! s:find_commit_meta(gita, commit) abort " {{{
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[ 1 : 2 ]
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let remote = a:gita.git.get_branch_remote(lhs)
    " 'git diff A...B' is equivalent to 'git diff $(git-merge-base A B) B'
    let lhs = s:find_common_ancestor(a:gita, lhs, rhs)
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[ 1 : 2 ]
    let remote = a:gita.git.get_branch_remote(lhs)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
  else
    let lhs = empty(a:commit) ? 'HEAD' : a:commit
    let rhs = ''
    let remote = a:gita.git.get_branch_remote(lhs)
  endif
  let lhs = s:find_remote_branch(a:gita, lhs)
  let rhs = s:find_remote_branch(a:gita, rhs)
  let remote = empty(remote) ? 'origin' : remote
  let remote_url = a:gita.git.get_remote_url(remote)
  return [lhs, rhs, remote, remote_url]
endfunction " }}}
function! s:translate_url(url, scheme_name, translation_patterns) abort " {{{
  for [domain, info] in items(a:translation_patterns)
    for pattern in info[0]
      let pattern = substitute(pattern, '\C' . '%domain', domain, 'g')
      if a:url =~# pattern
        let scheme = get(info[1], a:scheme_name, info[1]['_'])
        let repl = substitute(a:url, '\C' . pattern, scheme, 'g')
        return repl
      endif
    endfor
  endfor
  return ''
endfunction " }}}
function! s:retrieve_url(options) abort "{{{
  let gita = gita#get(a:options.file)
  let commit = get(a:options, 'branch', a:options.commit)
  let abspath = gita#utils#path#unix_abspath(a:options.file)
  let relpath = gita.git.get_relative_path(abspath)

  " get selected region
  let line_start = get(a:options, 'line_start', 0)
  let line_end   = get(a:options, 'line_end', 0)
  let line_end   = line_start == line_end ? 0 : line_end

  " normalize commit to figure out remote, commit, and remote_url
  let [commit1, commit2, remote, remote_url] = s:find_commit_meta(gita, commit)
  let revision1 = gita.git.get_remote_hash(remote, commit1)
  let revision2 = gita.git.get_remote_hash(remote, commit2)

  " create a URL
  let data = {
        \ 'path':       gita#utils#path#unix_relpath(relpath),
        \ 'commit1':    commit1,
        \ 'commit2':    commit2,
        \ 'revision1':  revision1,
        \ 'revision2':  revision2,
        \ 'remote':     remote,
        \ 'line_start': line_start,
        \ 'line_end':   line_end,
        \}
  let format_map = {
        \ 'pt': 'path',
        \ 'c1': 'commit1',
        \ 'c2': 'commit2',
        \ 'r1': 'revision1',
        \ 'r2': 'revision2',
        \ 'ls': 'line_start',
        \ 'le': 'line_end',
        \}
  let translation_patterns = extend(
        \ deepcopy(g:gita#features#browse#translation_patterns),
        \ g:gita#features#browse#extra_translation_patterns,
        \)
  let url = s:translate_url(
        \ remote_url,
        \ get(a:options, 'scheme', '_'),
        \ translation_patterns
        \)
  if !empty(url)
    return gita#utils#format_string(url, format_map, data)
  endif
  redraw
  call gita#utils#prompt#warn(printf(
        \ 'No url translation pattern for "%s" is found.',
        \ remote_url,
        \))
  if gita#utils#prompt#asktf('Do you want to open a help for adding extra translation patterns?')
    help g:gita#features#browse#extra_translation_patterns
  endif
  return ''
endfunction " }}}

function! gita#features#browse#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#browse#default_options),
          \ options)
    if !empty(options.__unknown__)
      let options['--'] = options.__unknown__
    endif
    call gita#action#exec(
          \ 'browse',
          \ options.__range__,
          \ options
          \)
  endif
endfunction " }}}
function! gita#features#browse#complete(arglead, cmdline, cursorpos) abort " {{{
  let candidates = s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}
function! gita#features#browse#action(candidates, options, config) abort " {{{
  if empty(a:candidates)
    return
  endif
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let urls = []
  for candidate in a:candidates
    let url = s:retrieve_url(extend({
          \ 'file': gita#utils#sget([a:options, candidate], 'path'),
          \ 'commit': gita#utils#sget([a:options, candidate], 'commit'),
          \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
          \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
          \ 'scheme': gita#utils#sget([a:options, candidate], 'scheme'),
          \}, a:options))
    if !empty(url)
      call add(urls, url)
    endif
  endfor
  if empty(urls)
    return
  endif
  redraw!
  for url in urls
    if get(a:options, 'echo')
      call gita#utils#prompt#echo(url)
    elseif get(a:options, 'yank')
      call gita#utils#clip(url)
      if get(a:config, 'echo', 'both') ==# 'both'
        call gita#utils#prompt#echo(printf(
              \ '"%s" is yanked.',
              \ url,
              \))
      endif
    else
      call s:F.open(url)
      if get(a:config, 'echo', 'both') ==# 'both'
        call gita#utils#prompt#echo(printf(
              \ '"%s" is opened.',
              \ url,
              \))
      endif
    endif
  endfor
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
