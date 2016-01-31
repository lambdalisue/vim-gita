let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:StringExt = s:V.import('Data.StringExt')
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
  let lhs_remote = s:GitInfo.get_branch_merge(config, lhs, 1)
  let rhs_remote = s:GitInfo.get_branch_merge(config, rhs, 1)
  let remote = empty(remote) ? 'origin' : remote
  let remote_url = s:GitInfo.get_remote_url(config, remote)
  return [lhs, rhs, remote, remote_url]
endfunction
function! s:translate_url(url, scheme_name, translation_patterns) abort
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
endfunction
function! s:find_url(git, commit, filename, options) abort
  let relpath = s:Path.unixpath(
        \ s:Git.get_relative_path(a:git, a:filename),
        \)
  " get selected region
  if has_key(a:options, 'selection')
    let line_start = get(a:options.selection, 0, 0)
    let line_end   = get(a:options.selection, 1, 0)
  else
    let line_start = 0
    let line_end = 0
  endif
  let line_end   = line_start == line_end ? 0 : line_end

  " normalize commit to figure out remote, commit, and remote_url
  let [commit1, commit2, remote, remote_url] = s:find_commit_meta(a:git, a:commit)
  let revision1 = s:GitInfo.get_remote_hash(a:git, remote, commit1)
  let revision2 = s:GitInfo.get_remote_hash(a:git, remote, commit2)

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
        \ get(a:options, 'scheme', '_'),
        \ translation_patterns
        \)
  if empty(url)
    call gita#throw(printf(
          \ 'Warning: No url translation pattern for "%s" is found.',
          \ remote_url,
          \))
  endif
  return s:StringExt.format(url, format_map, data)
endfunction

function! gita#command#browse#call(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  let local_branch = s:GitInfo.get_local_branch(git)
  let commit = empty(options.commit) ? local_branch.name : options.commit
  let commit = gita#variable#get_valid_range(commit)
  if empty(options.filenames)
    let filenames = ['%']
  endif
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(v:val)',
        \)
  let urls = map(copy(filenames), 's:find_url(git, commit, v:val, options)')
  return {
        \ 'commit': commit,
        \ 'filenames': filenames,
        \ 'urls': urls,
        \}
endfunction
function! gita#command#browse#open(...) abort
  let options = get(a:000, 0, {})
  let result = gita#command#browse#call(options)
  if empty(result)
    return
  endif
  for url in result.urls
    call s:File.open(url)
  endfor
endfunction
function! gita#command#browse#echo(...) abort
  let options = get(a:000, 0, {})
  let result = gita#command#browse#call(options)
  if empty(result)
    return
  endif
  for url in result.urls
    echo url
  endfor
endfunction
function! gita#command#browse#yank(...) abort
  let options = get(a:000, 0, {})
  let result = gita#command#browse#call(options)
  if empty(result)
    return
  endif
  call gita#util#clip(join(result.urls, "\n"))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita browse',
          \ 'description': 'Browse a content of the remote in a system default browser',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--open', '-o',
          \ 'Open a URL of a selected region of the remote in a system default browser (Default)', {
          \   'conflicts': ['yank', 'echo'],
          \})
    call s:parser.add_argument(
          \ '--yank', '-y',
          \ 'Yank a URL of a selected region of the remote.', {
          \   'conflicts': ['open', 'echo'],
          \})
    call s:parser.add_argument(
          \ '--echo', '-e',
          \ 'Echo a URL of a selected region of the remote.', {
          \   'conflicts': ['open', 'yank'],
          \})
    call s:parser.add_argument(
          \ '--scheme', '-s',
          \ 'Which scheme to determine remote URL.', {
          \   'type': s:ArgumentParser.types.value,
          \   'default': '_',
          \})
    call s:parser.add_argument(
          \ '--line-start',
          \ 'Start line for the selection', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ '--line-end',
          \ 'End line for the selection', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to see.',
          \   'If nothing is specified, it open a remote content of origin/HEAD.',
          \   'If <commit> is specified, it open a remote content of the named <commit>.',
          \   'If <commit1>..<commit2> is specified, it try to open a diff page of the remote content',
          \   'If <commit1>...<commit2> is specified, it try to open a diff open of the remote content',
          \], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    function! s:parser.hooks.pre_validate(options) abort
      if empty(s:parser.get_conflicted_arguments('open', a:options))
        let a:options.open = 1
      endif
    endfunction
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'line-start')
        let a:options.line_start = a:options['line-start']
        unlet a:options['line-start']
      endif
      if has_key(a:options, 'line-end')
        let a:options.line_end = a:options['line-end']
        unlet a:options['line-end']
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#browse#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  if empty(options.__unknown__)
    let options.filenames = ['%']
  else
    let options.filenames = options.__unknown__
  endif
  if len(options.filenames) == 1 && expand(options.filenames[0]) ==# expand('%')
    let options.selection = options.__range__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#browse#default_options),
        \ options,
        \)
  if get(options, 'yank')
    call gita#command#browse#yank(options)
  elseif get(options, 'echo')
    call gita#command#browse#echo(options)
  else
    call gita#command#browse#open(options)
  endif
endfunction
function! gita#command#browse#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#browse', {
      \ 'default_options': {},
      \ 'translation_patterns': {
      \   'github.com': [
      \     [
      \       '\vhttps?://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit://(%domain)/(.{-})/(.{-})%(\.git)?$',
      \       '\vgit\@(%domain):(.{-})/(.{-})%(\.git)?$',
      \       '\vssh://git\@(%domain)/(.{-})/(.{-})%(\.git)?$',
      \     ], {
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
      \       '_':     'https://\1/\2/\3/src/%c1/%pt%{#cl-|}ls',
      \       'exact': 'https://\1/\2/\3/src/%r1/%pt%{#cl-|}ls',
      \       'blame': 'https://\1/\2/\3/annotate/%c1/%pt',
      \       'diff':  'https://\1/\2/\3/diff/%pt?diff1=%c1&diff2=%c2',
      \     },
      \   ],
      \ },
      \ 'extra_translation_patterns': {},
      \})
