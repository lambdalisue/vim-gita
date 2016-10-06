let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'deleted': 0,
        \ 'modified': 0,
        \ 'others': 0,
        \ 'ignored': 0,
        \ 'staged': 0,
        \ 'unstaged': 0,
        \ 'killed': 0,
        \}, a:options)
  return gita#content#build_bufname('ls-files', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.cached ? 'cached' : '',
        \   options.deleted ? 'deleted' : '',
        \   options.modified ? 'modified' : '',
        \   options.others ? 'others' : '',
        \   options.ignored ? 'ignored' : '',
        \   options.staged ? 'staged' : '',
        \   options.unstaged ? 'unstaged' : '',
        \   options.killed ? 'killed' : '',
        \ ],
        \})
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'cached': 1,
        \ 'deleted': 1,
        \ 'modified': 1,
        \ 'others': 1,
        \ 'ignored': 1,
        \ 'stage': 1,
        \ 'directory': 1,
        \ 'no-empty-directory': 1,
        \ 'unmerged': 1,
        \ 'killed': 1,
        \ 'exclude-standard': 1,
        \ 'error-unmatch': 1,
        \ 'full-name': 1,
        \ 'abbrev': 1,
        \ 'exclude': '--%k %v',
        \ 'exclude-from': '--%k %v',
        \ 'exclude-per-directory': '--%k %v',
        \ 'with-tree': '--%k %v',
        \})
  let args = [
        \ 'ls-files',
        \ '--full-name',
        \] + args + ['--'] + map(
        \  copy(get(a:options, 'filenames', [])),
        \  'gita#normalize#relpath(a:git, v:val)'
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
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#content#ls_files#disable_default_mappings)

  if g:gita#content#ls_files#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#ls_files#primary_action_mapping
        \)
endfunction

function! s:get_candidates(startline, endline) abort
  let candidates = gita#meta#get_for('^ls-files$', 'candidates', [])
  let records = getline(a:startline, a:endline)
  return gita#action#filter(candidates, records, 'path')
endfunction

function! s:extend_filename(filename) abort
  return { 'path': a:filename }
endfunction

function! s:get_prologue(git) abort
  let candidates = gita#meta#get_for('^ls-files$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ '%d file%s in %s %s',
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ a:git.repository_name,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^ls-files$', a:options)
  let content = s:execute_command(options)
  let candidates = map(content, 's:extend_filename(v:val)')
  call gita#meta#set('content_type', 'ls-files')
  call gita#meta#set('options', options)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-files
  setlocal buftype=nofile nobuflisted
  setlocal bufhidden=wipe
  setlocal nomodifiable
  call gita#content#ls_files#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#ls_files#open(options) abort
  let options = extend({
        \ 'opener': 'botright 10 split',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  call gita#util#cascade#set('ls-files', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#ls_files#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^ls-files$', 'candidates', [])),
        \ 'v:val.path',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#ls_files#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('ls-files')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#ls_files', {
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
