let s:V = gita#vital()
let s:String = s:V.import('Data.String')
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'no-index': 0,
        \ 'untracked': 0,
        \ 'ignore-case': 0,
        \}, a:options)
  return gita#content#build_bufname('grep', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.cached ? 'cached' : '',
        \   options['no-index'] ? 'no-index' : '',
        \   options.untracked ? 'untracked' : '',
        \   options['ignore-case'] ? 'ignore-case' : '',
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'cached': 1,
        \ 'no-index': 1,
        \ 'untracked': 1,
        \ 'no-exclude-standard': 1,
        \ 'exclude-standard': 1,
        \ 'text': 1,
        \ 'ignore-case': 1,
        \ 'I': 1,
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
        \ '--no-color',
        \ '--line-number',
        \ '--full-name',
        \ a:options.commit,
        \]
  for pattern in a:options.patterns
    let args += ['-e', pattern]
  endfor
  let args += ['--'] + a:options.filenames
  let git = gita#core#get_or_fail()
  return gita#process#execute(git, args, { 'quiet': 1 })
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#content#grep#disable_default_mappings)

  if g:gita#content#grep#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#grep#primary_action_mapping
        \)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let candidates = gita#meta#get_for('^grep$', 'candidates', [])
  return gita#action#find_candidate(candidates, record, 'record')
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
  let commit = gita#meta#get_for('^grep$', 'commit', '')
  let candidates = gita#meta#get_for('^grep$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ '%d match%s in %s of %s %s',
        \ ncandidates,
        \ ncandidates == 1 ? '' : 'es',
        \ empty(commit) ? 'INDEX' : commit,
        \ a:git.repository_name,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^grep$', a:options, {
        \ 'commit': '',
        \ 'filenames': [],
        \})
  let content = s:execute_command(options)
  let candidates = s:GitParser.parse_match(content)
  let candidates = s:extend_matches(candidates, winwidth(0))
  call gita#meta#set('content_type', 'grep')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('patterns', options.patterns)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-grep
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#grep#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#grep#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#grep#default_opener
        \ : options.opener
  call gita#util#cascade#set('grep', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#grep#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^grep$', 'candidates', [])),
        \ 'v:val.record',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
  let patterns = gita#meta#get_for('^grep$', 'patterns')
  for pattern in patterns
    execute printf(
          \ 'syntax match GitaKeyword /%s/ contained',
          \ s:String.escape_pattern(pattern),
          \)
  endfor
endfunction

function! gita#content#grep#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('grep')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#grep', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})
