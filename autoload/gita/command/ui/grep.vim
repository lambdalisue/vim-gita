let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:StringExt = s:V.import('Data.StringExt')
let s:Git = s:V.import('Git')
let s:candidate_offset = 0

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

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let candidates = gita#meta#get_for('grep', 'candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#command#ui#grep#disable_default_mappings)
  if g:gita#command#ui#grep#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#grep#primary_action_mapping
        \)
endfunction

function! s:get_bufname(options) abort
  let options = extend({
        \ 'pattern': '',
        \ 'commit': '',
        \ 'cached': 0,
        \ 'no-index': 0,
        \ 'untracked': 0,
        \}, a:options)
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'grep',
        \ 'extra_options': [
        \   commit,
        \ ],
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^grep$', a:options, {
        \ 'selection': [],
        \})
  let options['full-name'] = 1
  let options['no-color'] = 1
  let options['line-number'] = 1
  let result = gita#command#grep#call(options)
  let candidates = map(
        \ copy(result.content),
        \ 's:extend_match(git, v:val)'
        \)
  call gita#meta#set('content_type', 'grep')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'selection',
        \]))
  call gita#meta#set('pattern', result.pattern)
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('candidates', candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-grep
  setlocal buftype=nofile nobuflisted
  setlocal nowrap
  setlocal cursorline
  setlocal nomodifiable
  call gita#command#ui#grep#redraw()
  call gita#util#select(options.selection)
endfunction

function! s:define_syntax() abort
  syntax match GitaComment    /\%^.*$/
  let pattern = gita#meta#get('pattern')
  execute printf(
        \ 'syntax match GitaKeyword /%s/',
        \ s:StringExt.escape_regex(pattern),
        \)
endfunction

function! gita#command#ui#grep#autocmd(name, options, attributes) abort
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita:[^:\\/]\+:grep:\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ expand('<afile>'),
          \))
  endif
  let options = gita#util#cascade#get('grep')
  let options.commit = gita#variable#get_valid_range(m[1])
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#grep#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#grep#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('grep', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
endfunction

function! gita#command#grep#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let candidates = gita#meta#get('candidates', [])
  let contents = s:format_matches(candidates, winwidth(0))
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
  call s:define_syntax()
endfunction


call gita#util#define_variables('command#ui#grep', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})
