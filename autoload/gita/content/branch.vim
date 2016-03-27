let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'all': 0,
        \ 'remotes': 0,
        \ 'merged': 0,
        \ 'no-merged': 0,
        \}, a:options)
  return gita#content#build_bufname('branch', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.all ? 'all' : '',
        \   options.remotes ? 'remotes' : '',
        \   options.merged ? 'merged' : '',
        \   options['no-merged'] ? 'no-merged' : '',
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'all': 1,
        \ 'remotes': 1,
        \ 'list': '--%k %v',
        \ 'contains': '--%k %v',
        \ 'merged': '--%k %v',
        \ 'no-merged': '--%k %v',
        \})
  let args = [
        \ 'branch',
        \ '--no-column',
        \ '--no-color',
        \ '--no-abbrev',
        \] + args
  let git = gita#core#get_or_fail()
  return gita#process#execute(git, args, {
        \ 'quiet': 1,
        \ 'encode_output': 0,
        \})
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'branch', 'merge', 'rebase',
        \], g:gita#content#branch#disable_default_mappings)

  if g:gita#content#branch#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#branch#primary_action_mapping
        \)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let branches = gita#meta#get_for('^branch$', 'branches', [])
  return gita#action#find_candidate(branches, record, 'record')
endfunction

function! s:get_prologue(git) abort
  let branches = gita#meta#get_for('^branch$', 'branches', [])
  let nbranches = len(branches)
  return printf(
        \ '%d branch%s in %s %s',
        \ nbranches,
        \ nbranches == 1 ? '' : 'es',
        \ a:git.repository_name,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^branch$', a:options, {
        \ 'all': 0,
        \ 'remotes': 0,
        \ 'list': 0,
        \ 'contains': 0,
        \ 'merged': 0,
        \ 'no-merged': 0,
        \})
  let content = s:execute_command(options)
  let branches = s:GitParser.parse_branch(content)
  call gita#meta#set('content_type', 'branch')
  call gita#meta#set('options', options)
  call gita#meta#set('branches', branches)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-branch
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#branch#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#branch#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#branch#default_opener
        \ : options.opener
  call gita#util#cascade#set('branch', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#branch#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^branch$', 'branches', [])),
        \ 'v:val.record',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#branch#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('branch')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#branch', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-branch-checkout-track)',
      \ 'disable_default_mappings': 0,
      \})
