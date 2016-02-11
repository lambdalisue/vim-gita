let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:StringExt = s:V.import('Data.StringExt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'delete',
        \ 'force',
        \ 'move',
        \ 'remotes',
        \ 'all',
        \ 'list',
        \ 'track', 'no-track',
        \ 'set-upstream', 'set-upstream-to', 'unset-upstream',
        \ 'contains',
        \ 'merged', 'no-merged',
        \ 'points-at',
        \])
  return options
endfunction
function! s:get_branch_content(git, query, commit, directories, options) abort
  let options = s:pick_available_options(a:options)
  let options['no-column'] = 1
  let options['no-color'] = 1
  let options['no-abbrev'] = 1
  let options['query'] = a:query
  if !empty(a:commit)
    let options['commit'] = a:commit
  endif
  if !empty(a:directories)
    let options['--'] = a:directories
  endif
  let result = gita#execute(a:git, 'branch', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! s:extend_match(git, match) abort
  let candidate = {}
  let candidate.record = a:match
  if a:match =~# '^[^:]\+:.\{-}:\d\+:.*$'
    let m = matchlist(
          \ a:match,
          \ '^\([^:]\+\):\(.\{-}\):\(\d\+\):\(.*\)$',
          \)
    let candidate.commit = m[1]
    let candidate.relpath = m[2]
    let candidate.path = s:Git.get_absolute_path(
          \ a:git, s:Path.realpath(m[2]),
          \)
    let candidate.selection = [m[3]]
    let candidate.content = m[4]
  else
    let m = matchlist(
          \ a:match,
          \ '^\(.\{-}\):\(\d\+\):\(.*\)$',
          \)
    let candidate.commit = ''
    let candidate.relpath = m[1]
    let candidate.path = s:Git.get_absolute_path(
          \ a:git, s:Path.realpath(m[1]),
          \)
    let candidate.selection = [m[2]]
    let candidate.content = m[3]
  endif
  return candidate
endfunction
function! s:format_match(match, format) abort
  return printf(a:format,
        \ a:match.relpath . ':' . a:match.selection[0],
        \ a:match.content,
        \)
endfunction
function! s:format_matches(matches, width) abort
  let max_path = 0
  for candidate in a:matches
    let prefix = candidate.relpath . ':' . candidate.selection[0]
    if len(prefix) > max_path
      let max_path = len(prefix)
    endif
  endfor
  let format = printf(
        \ '%%-%ds | %%s',
        \ max_path,
        \)
  let content = map(copy(a:matches),
        \ 's:format_match(v:val, format)',
        \)
  return content
endfunction
function! s:get_header_string(git) abort
  let commit = gita#get_meta('commit', '')
  let query = gita#get_meta('query', '')
  let candidates = gita#get_meta('candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files contain "%s" in <%s> (%d file%s) %s',
        \ query,
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let candidates = gita#get_meta('candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#branch#edit()
  endfunction

  call gita#action#includes(
        \ g:gita#command#branch#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'add', 'rm', 'reset', 'checkout',
        \   'stage', 'unstage', 'toggle', 'discard',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \   'commit',
        \])

  if g:gita#command#branch#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#branch#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#branch#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#branch#bufname(...) abort
  let options = gita#option#init('^branch$', get(a:000, 0, {}), {
        \ 'query': '',
        \ 'commit': '',
        \ 'cached': 0,
        \ 'no-index': 0,
        \ 'untracked': 0,
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'branch',
        \ 'extra_options': [
        \   empty(options.cached) ? '' : 'cached',
        \   empty(options['no-index']) ? '' : 'no-index',
        \   empty(options.untracked) ? '' : 'untracked',
        \   options.query,
        \ ],
        \ 'commitish': commit,
        \ 'path': '',
        \})
endfunction
function! gita#command#branch#call(...) abort
  let options = gita#option#init('^branch$', get(a:000, 0, {}), {
        \ 'query': '',
        \ 'commit': '',
        \ 'directories': [],
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_commit(options.commit, {
        \ '_allow_empty': 1,
        \})
  let content = s:get_branch_content(
        \ git, options.query, commit, options.directories, options
        \)
  let candidates = map(
        \ copy(content),
        \ 's:extend_match(git, v:val)'
        \)
  let result = {
        \ 'query': options.query,
        \ 'commit': commit,
        \ 'content': content,
        \ 'candidates': candidates,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#branch#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#branch#default_opener
        \ : options.opener
  let bufname = gita#command#branch#bufname(options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'manipulation_panel',
        \})
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#branch#edit(options)
endfunction
function! gita#command#branch#edit(...) abort
  let options = get(a:000, 0, {})
  let result = gita#command#branch#call(options)
  call gita#set_meta('content_type', 'branch')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener',
        \]))
  call gita#set_meta('query', result.query)
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('candidates', result.candidates)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_branch
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> nested call s:on_BufReadCmd()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-branch
  setlocal buftype=nofile nobuflisted
  setlocal nowrap
  setlocal cursorline
  setlocal nomodifiable
  if exists('#BufReadPre')
    call gita#util#doautocmd('BufReadPre')
  endif
  call gita#command#branch#redraw()
  if exists('#BufReadPost')
    call gita#util#doautocmd('BufReadPost')
  endif
endfunction
function! gita#command#branch#redraw() abort
  let git = gita#get_or_fail()
  let prologue = s:List.flatten([
        \ [s:get_header_string(git)],
        \ gita#action#mapping#get_visibility()
        \   ? map(gita#action#get_mapping_help(), '"| " . v:val')
        \   : []
        \])
  let candidates = gita#get_meta('candidates', [])
  let contents = s:format_matches(candidates, winwidth(0))
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita branch',
          \ 'description': 'Print lines matching a pattern',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to branch.',
          \   'If nothing is specified, it branch a content in an index or working tree.',
          \   'If <commit> is specified, it branch a content in the named <commit>.',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ 'query', [
          \   'A query.',
          \ ], {
          \})
    " TODO: Add more arguments
    function! s:parser.hooks.post_validate(options) abort
      if !has_key(a:options, 'query')
        let a:options.query = get(a:options, 'commit', '')
        let a:options.commit = ''
      endif
    endfunction
  endif
  return s:parser
endfunction
function! gita#command#branch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#branch#default_options),
        \ options,
        \)
  call gita#command#branch#open(options)
endfunction
function! gita#command#branch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#branch#define_highlights() abort
  highlight default link GitaComment    Comment
  highlight default link GitaKeyword    Keyword
endfunction
function! gita#command#branch#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
  let query = gita#get_meta('query')
  execute printf(
        \ 'syntax match GitaKeyword /%s/',
        \ s:StringExt.escape_regex(query),
        \)
endfunction

call gita#util#define_variables('command#branch', {
      \ 'default_options': {},
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'enable_default_mappings': 1,
      \})


