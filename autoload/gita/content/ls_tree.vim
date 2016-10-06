let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'commit': 'HEAD',
        \}, a:options)
  return gita#content#build_bufname('ls-tree', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.commit,
        \ ],
        \})
endfunction

function! s:args_from_options(git, options) abort
  let args = [
        \ 'ls-tree',
        \ '--full-name',
        \ '--full-tree',
        \ '--name-only',
        \ '-r',
        \ gita#normalize#commit(a:git, a:options.commit),
        \ '--',
        \] + map(
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
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#content#ls_tree#disable_default_mappings)

  if g:gita#content#ls_tree#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#ls_tree#primary_action_mapping
        \)
endfunction

function! s:get_candidates(startline, endline) abort
  let candidates = gita#meta#get_for('^ls-tree$', 'candidates', [])
  let records = getline(a:startline, a:endline)
  return gita#action#filter(candidates, records, 'path')
endfunction

function! s:extend_filename(filename) abort
  return { 'path': a:filename }
endfunction

function! s:get_prologue(git) abort
  let commit = gita#meta#get_for('^ls-tree$', 'commit', '')
  let candidates = gita#meta#get_for('^ls-tree$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ '%d file%s in %s of %s %s',
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ empty(commit) ? 'INDEX' : commit,
        \ a:git.repository_name,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^ls-tree$', a:options)
  let content = s:execute_command(options)
  let candidates = map(content, 's:extend_filename(v:val)')
  call gita#meta#set('content_type', 'ls-tree')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-tree
  setlocal buftype=nofile nobuflisted
  setlocal bufhidden=wipe
  setlocal nomodifiable
  call gita#content#ls_tree#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#ls_tree#open(options) abort
  let options = extend({
        \ 'opener': 'botright 10 split',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  call gita#util#cascade#set('ls-tree', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#ls_tree#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^ls-tree$', 'candidates', [])),
        \ 'v:val.path',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#ls_tree#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('ls-tree')
  let options.commit = get(a:bufinfo.extra_options, 0, '')
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#ls_tree', {
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
