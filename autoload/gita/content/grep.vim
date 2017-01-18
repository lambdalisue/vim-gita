let s:V = gita#vital()
let s:String = s:V.import('Data.String')
let s:Console = s:V.import('Vim.Console')
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')

function! s:assign_pattern(options) abort
  if empty(get(a:options, 'patterns'))
    let pattern = s:Console.ask('Please input a grep pattern: ')
    if empty(pattern)
      call gita#throw('Cancel')
    endif
    let a:options.patterns = [pattern]
  endif
  return a:options
endfunction

function! s:build_bufname(options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'commit': '',
        \}, a:options)
  return gita#content#build_bufname('grep', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.cached ? 'cached' : 'worktree',
        \   options.commit,
        \ ],
        \})
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'cached': 1,
        \ 'no-index': 1,
        \ 'untracked': 1,
        \ 'no-exclude-standard': 1,
        \ 'exclude-standard': 1,
        \ 'text': 1,
        \ 'ignore-case': 1,
        \ 'max-depth': 1,
        \ 'word-regexp': 1,
        \ 'invert-match': 1,
        \ 'extended-regexp': 1,
        \ 'basic-regexp': 1,
        \ 'perl-regexp': 1,
        \ 'fixed-strings': 1,
        \ 'all-match': 1,
        \})
  let args = [
        \ 'grep',
        \ '-I',
        \ '--no-color',
        \ '--line-number',
        \ '--full-name',
        \ gita#normalize#commit(a:git, a:options.commit),
        \]
  for pattern in a:options.patterns
    let args += ['-e' . pattern]
  endfor
  let args += ['--'] + map(
        \ copy(get(a:options, 'filenames', [])),
        \ 'gita#normalize#relpath(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! s:execute_command(options) abort
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, a:options)
  let content = gita#process#execute(git, args, {
        \ 'quiet': 1,
        \ 'encode_output': 0,
        \}).content
  return filter(content, '!empty(v:val)')
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidates'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame', 'quickfix',
        \], g:gita#content#grep#disable_default_mappings)

  if g:gita#content#grep#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#grep#primary_action_mapping
        \)
endfunction

function! s:get_candidates(startline, endline) abort
  let candidates = gita#meta#get_for('^grep$', 'candidates', [])
  let records = getline(a:startline, a:endline)
  return gita#action#filter(candidates, records, 'record')
endfunction

function! s:format_match(match, format) abort
  return printf(a:format,
        \ a:match.path . ':' . a:match.selection[0],
        \ a:match.content,
        \)
endfunction

function! s:extend_matches(matches, width) abort
  let max_path = 0
  for candidate in a:matches
    let prefix = candidate.path . ':' . candidate.selection[0]
    if len(prefix) > max_path
      let max_path = len(prefix)
    endif
  endfor
  let format = printf('%%-%ds | %%s', max_path)
  return map(copy(a:matches),
        \ 'extend(v:val, { ''record'': s:format_match(v:val, format) })',
        \)
endfunction

function! s:get_prologue(git) abort
  let cached = gita#meta#get_for('^grep$', 'cached', '')
  let commit = gita#meta#get_for('^grep$', 'commit', '')
  let candidates = gita#meta#get_for('^grep$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ '%d match%s in %s of %s %s',
        \ ncandidates,
        \ ncandidates == 1 ? '' : 'es',
        \ empty(commit) ? (cached ? 'INDEX' : 'WORKTREE') : commit,
        \ a:git.repository_name,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^grep$', a:options)
  let options = s:assign_pattern(options)
  let content = s:execute_command(options)
  let candidates = s:GitParser.parse_match(content)
  let candidates = s:extend_matches(candidates, winwidth(0))
  call gita#meta#set('content_type', 'grep')
  call gita#meta#set('options', options)
  call gita#meta#set('cached', options.cached)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('patterns', options.patterns)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-grep
  setlocal buftype=nofile nobuflisted
  setlocal bufhidden=wipe
  setlocal nomodifiable
  call gita#content#grep#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#grep#open(options) abort
  let options = extend({
        \ 'opener': 'botright 10 split',
        \ 'window': 'manipulation_window',
        \ 'patterns': [],
        \}, a:options)
  let options = s:assign_pattern(options)
  let bufname = s:build_bufname(options)
  call gita#util#cascade#set('grep', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#grep#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^grep$', 'candidates', [])),
        \ 'v:val.record'
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
  let patterns = map(
        \ copy(gita#meta#get_for('^grep$', 'patterns')),
        \ 's:String.escape_pattern(v:val)'
        \)
  execute printf(
        \ 'syntax match GitaKeyword /\%%(%s\)/ contained',
        \ join(patterns, '\|')
        \)
endfunction

function! gita#content#grep#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('grep')
  let options.cached = get(a:bufinfo.extra_options, 0, '') ==# 'cached'
  let options.commit = get(a:bufinfo.extra_options, 1, '')
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#grep', {
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
