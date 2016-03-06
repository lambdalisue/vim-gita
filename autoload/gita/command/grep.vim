let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Guard = s:V.import('Vim.Guard')
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
        \ 'cached',
        \ 'no-index',
        \ 'untracked',
        \ 'no-exclude-standard',
        \ 'exclude-standard',
        \ 'text',
        \ 'ignore-case',
        \ 'I',
        \ 'max-depth',
        \ 'word-regexp',
        \ 'invert-match',
        \ 'extended-regexp',
        \ 'basic-regexp',
        \ 'perl-regexp',
        \ 'fixed-strings',
        \ 'all-match',
        \])
  return options
endfunction
function! s:get_grep_content(git, pattern, commit, directories, options) abort
  let options = s:pick_available_options(a:options)
  let options['full-name'] = 1
  let options['no-color'] = 1
  let options['line-number'] = 1
  let options['pattern'] = a:pattern
  if !empty(a:commit)
    let options['commit'] = a:commit
  endif
  if !empty(a:directories)
    let options['--'] = a:directories
  endif
  let result = gita#execute(a:git, 'grep', options)
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
  let commit = gita#meta#get('commit', '')
  let pattern = gita#meta#get('pattern', '')
  let candidates = gita#meta#get('candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files contain "%s" in <%s> (%d file%s) %s',
        \ pattern,
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let candidates = gita#meta#get('candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction
function! s:define_actions() abort
  call gita#action#attach(function('s:get_entry'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#command#grep#disable_default_mappings)
  if g:gita#command#grep#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#grep#default_action_mapping
        \)
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#grep#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#grep#bufname(options) abort
  let options = extend({
        \ 'pattern': '',
        \ 'commit': '',
        \ 'cached': 0,
        \ 'no-index': 0,
        \ 'untracked': 0,
        \}, a:options)
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'grep',
        \ 'extra_options': [
        \   empty(options.cached) ? '' : 'cached',
        \   empty(options['no-index']) ? '' : 'no-index',
        \   empty(options.untracked) ? '' : 'untracked',
        \   options.pattern,
        \ ],
        \ 'commitish': commit,
        \ 'path': '',
        \})
endfunction
function! gita#command#grep#call(...) abort
  let options = gita#option#cascade('^grep$', get(a:000, 0, {}), {
        \ 'pattern': '',
        \ 'commit': '',
        \ 'directories': [],
        \})
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_commit(options.commit, {
        \ '_allow_empty': 1,
        \})
  let content = s:get_grep_content(
        \ git, options.pattern, commit, options.directories, options
        \)
  let candidates = map(
        \ copy(content),
        \ 's:extend_match(git, v:val)'
        \)
  let result = {
        \ 'pattern': options.pattern,
        \ 'commit': commit,
        \ 'content': content,
        \ 'candidates': candidates,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#grep#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = gita#command#grep#bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#grep#default_opener
        \ : options.opener
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore+=BufReadCmd
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': 'manipulation_panel',
          \})
  finally
    call guard.restore()
  endtry
  call gita#command#grep#edit(options)
endfunction
function! gita#command#grep#edit(...) abort
  let options = gita#option#cascade('^grep$', {}, get(a:000, 0, {}))
  let result = gita#command#grep#call(options)
  call gita#meta#set('content_type', 'grep')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener',
        \]))
  call gita#meta#set('pattern', result.pattern)
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('candidates', result.candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_grep
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> nested call s:on_BufReadCmd()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-grep
  setlocal buftype=nofile nobuflisted
  setlocal nowrap
  setlocal cursorline
  setlocal nomodifiable
  call gita#command#grep#redraw()
endfunction
function! gita#command#grep#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let candidates = gita#meta#get('candidates', [])
  let contents = s:format_matches(candidates, winwidth(0))
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita grep',
          \ 'description': 'Print lines matching a pattern',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'search in index instead of in the work tree',
          \)
    call s:parser.add_argument(
          \ '--no-index',
          \ 'find in contents not managed by git',
          \)
    call s:parser.add_argument(
          \ '--untracked',
          \ 'search in both tracked and untracked files',
          \)
    call s:parser.add_argument(
          \ '--exclude-standard',
          \ 'ignore files specified via ".gitignore"',
          \)
    call s:parser.add_argument(
          \ '--invert-match', '-v',
          \ 'show non-matching lines',
          \)
    call s:parser.add_argument(
          \ '--ignore-case', '-i',
          \ 'case insensitive matching',
          \)
    call s:parser.add_argument(
          \ '--word-regexp', '-w',
          \ 'match patterns only at word boundaries',
          \)
    call s:parser.add_argument(
          \ '--text', '-a',
          \ 'process binary files as text',
          \)
    call s:parser.add_argument(
          \ '-I',
          \ 'don''t match patterns in binary files',
          \)
    call s:parser.add_argument(
          \ '--textconv',
          \ 'process binary files with textconv filters',
          \)
    call s:parser.add_argument(
          \ '--max-depth',
          \ 'descend at most DEPTH levels', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--extended-regexp', '-E',
          \ 'use extended POSIX regular expressions',
          \)
    call s:parser.add_argument(
          \ '--basic-regexp', '-G',
          \ 'use basic POSIX regular expressions (default)',
          \)
    call s:parser.add_argument(
          \ '--fixed-strings', '-F',
          \ 'interpret patterns as fixed strings',
          \)
    call s:parser.add_argument(
          \ '--perl-regexp', '-P',
          \ 'use Perl-compatible regular expressions',
          \)
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit which you want to grep.',
          \   'If nothing is specified, it grep a content in an index or working tree.',
          \   'If <commit> is specified, it grep a content in the named <commit>.',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ 'pattern', [
          \   'a match pattern',
          \ ], {
          \})
    function! s:parser.hooks.post_validate(options) abort
      if !has_key(a:options, 'pattern')
        let a:options.pattern = get(a:options, 'commit', '')
        let a:options.commit = ''
      endif
    endfunction
  endif
  return s:parser
endfunction
function! gita#command#grep#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#grep#default_options),
        \ options,
        \)
  call gita#command#grep#open(options)
endfunction
function! gita#command#grep#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#grep#define_highlights() abort
  highlight default link GitaComment    Comment
  highlight default link GitaKeyword    Keyword
endfunction
function! gita#command#grep#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
  let pattern = gita#meta#get('pattern')
  execute printf(
        \ 'syntax match GitaKeyword /%s/',
        \ s:StringExt.escape_regex(pattern),
        \)
endfunction

call gita#util#define_variables('command#grep', {
      \ 'default_options': {},
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})

