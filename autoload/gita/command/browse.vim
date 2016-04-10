let s:V = gita#vital()
let s:File = s:V.import('System.File')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
let s:GitInfo = s:V.import('Git.Info')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:find_commit_meta(git, commit) abort
  let config = s:GitInfo.get_repository_config(a:git)
  if a:commit =~# '^.\{-}\.\.\..*$'
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let remote = s:GitInfo.get_branch_remote(config, lhs)
    let lhs = s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
  elseif a:commit =~# '^.\{-}\.\..*$'
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let remote = s:GitInfo.get_branch_remote(config, lhs)
  else
    let lhs = empty(a:commit) ? 'HEAD' : a:commit
    let rhs = ''
    let remote = s:GitInfo.get_branch_remote(config, lhs)
  endif
  let remote = empty(remote) ? 'origin' : remote
  let remote_url = s:GitInfo.get_remote_url(config, remote)
  let remote_url = empty(remote_url)
        \ ? s:GitInfo.get_remote_url(config, 'origin')
        \ : remote_url
  return [lhs, rhs, remote, remote_url]
endfunction

function! s:translate_url(url, scheme_name, translation_patterns, repository) abort
  let symbol = a:repository ? '^' : '_'
  for [domain, info] in items(a:translation_patterns)
    for pattern in info[0]
      let pattern = substitute(pattern, '\C' . '%domain', domain, 'g')
      if a:url =~# pattern
        let scheme = get(info[1], a:scheme_name, info[1][symbol])
        let repl = substitute(a:url, '\C' . pattern, scheme, 'g')
        return repl
      endif
    endfor
  endfor
  return ''
endfunction

function! s:find_url(git, commit, filename, options) abort
  let relpath = s:Path.unixpath(
        \ s:Git.relpath(a:git, a:filename),
        \)
  " normalize commit to figure out remote, commit, and remote_url
  let [commit1, commit2, remote, remote_url] = s:find_commit_meta(a:git, a:commit)
  let revision1 = s:GitInfo.get_remote_hash(a:git, remote, commit1)
  let revision2 = s:GitInfo.get_remote_hash(a:git, remote, commit2)

  " get selected region
  if has_key(a:options, 'selection')
    let line_start = get(a:options.selection, 0, 0)
    let line_end   = get(a:options.selection, 1, 0)
  else
    let line_start = 0
    let line_end = 0
  endif
  let line_end = line_start == line_end ? 0 : line_end

  " create a URL
  let data = {
        \ 'path':       relpath,
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
        \ deepcopy(g:gita#command#browse#translation_patterns),
        \ g:gita#command#browse#extra_translation_patterns,
        \)
  let url = s:translate_url(
        \ remote_url,
        \ empty(a:filename) ? '^' : get(a:options, 'scheme', '_'),
        \ translation_patterns,
        \ empty(a:filename),
        \)
  if empty(url)
    call gita#throw(printf(
          \ 'Warning: No url translation pattern for "%s:%s" is found.',
          \ remote, commit1,
          \))
  endif
  return gita#util#formatter#format(url, format_map, data)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita browse',
          \ 'description': 'Browse a URL of the remote content',
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \ 'unknown_description': '<path>',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--repository', '-r',
          \ 'Use a URL of the repository instead',
          \)
    call s:parser.add_argument(
          \ '--open',
          \ 'Open a URL of a selected region of the remote in a system default browser (Default)', {
          \   'deniable': 1,
          \   'default': 1,
          \})
    call s:parser.add_argument(
          \ '--yank',
          \ 'Yank a URL of a selected region of the remote. (Default)', {
          \   'deniable': 1,
          \   'default': 1,
          \})
    call s:parser.add_argument(
          \ '--scheme', '-s',
          \ 'Which scheme to determine remote URL.', {
          \   'type': s:ArgumentParser.types.value,
          \   'default': '_',
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'A line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to see.',
          \   'If nothing is specified, it open a remote content of the current branch.',
          \   'If <commit> is specified, it open a remote content of the named <commit>.',
          \   'If <commit1>..<commit2> is specified, it try to open a diff page of the remote content',
          \   'If <commit1>...<commit2> is specified, it try to open a diff open of the remote content',
          \], {
          \   'complete': function('gita#util#complete#commit'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction

function! gita#command#browse#call(git, options) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'selection': [],
        \}, a:options)
  let local_branch = s:GitInfo.get_local_branch(a:git)
  let commit = empty(options.commit) ? local_branch.name : options.commit
  let filename = options.filename
  return s:find_url(a:git, commit, filename, options)
endfunction

function! gita#command#browse#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_filename(options)
  call gita#util#option#assign_selection(options)
  let git = gita#core#get_or_fail()
  let url = gita#command#browse#call(git, options)
  if get(options, 'yank')
    call gita#util#clip(url)
  endif
  if get(options, 'open')
    call gita#util#browse(url)
  endif
  echo url
endfunction

function! gita#command#browse#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#browse', {
      \ 'translation_patterns': {
      \   'github.com': [
      \     [
      \       '\vhttps?://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit\@(%domain):(.{-})/(.{-})%(\.git)?$',
      \       '\vssh://git\@(%domain)/(.{-})/(.{-})%(\.git)?$',
      \     ], {
      \       '^':     'https://\1/\2/\3/tree/%c1/',
      \       '_':     'https://\1/\2/\3/blob/%c1/%pt%{#L|}ls%{-L|}le',
      \       'exact': 'https://\1/\2/\3/blob/%r1/%pt%{#L|}ls%{-L|}le',
      \       'blame': 'https://\1/\2/\3/blame/%c1/%pt%{#L|}ls%{-L|}le',
      \     },
      \   ],
      \   'bitbucket.org': [
      \     [
      \       '\vhttps?://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit\@(%domain):(.{-})/(.{-})%(\.git)?$',
      \       '\vssh://git\@(%domain)/(.{-})/(.{-})%(\.git)?$',
      \     ], {
      \       '^':     'https://\1/\2/\3/branch/%c1/',
      \       '_':     'https://\1/\2/\3/src/%c1/%pt%{#cl-|}ls',
      \       'exact': 'https://\1/\2/\3/src/%r1/%pt%{#cl-|}ls',
      \       'blame': 'https://\1/\2/\3/annotate/%c1/%pt',
      \       'diff':  'https://\1/\2/\3/diff/%pt?diff1=%c1&diff2=%c2',
      \     },
      \   ],
      \ },
      \ 'extra_translation_patterns': {},
      \})
