let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:GitParser = s:V.import('Git.Parser')
let s:candidate_offset = 0

function! s:get_header_string(git) abort
  let branches = gita#meta#get_for('branch', 'branches', [])
  let nbranches = len(branches)
  return printf(
        \ 'There are %d branch%s %s',
        \ nbranches,
        \ nbranches == 1 ? '' : 'es',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let candidates = gita#meta#get_for('branch', 'branches', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'branch', 'merge', 'rebase',
        \], g:gita#ui#branch#disable_default_mappings)

  if g:gita#ui#branch#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#ui#branch#primary_action_mapping
        \)
  execute printf(
        \ 'nmap <buffer> <S-Return> %s',
        \ g:gita#ui#branch#secondary_action_mapping
        \)
endfunction

function! s:get_bufname(options) abort
  let options = extend({
        \ 'all': 0,
        \ 'remotes': 0,
        \}, a:options)
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'branch',
        \ 'extra_option': [
        \   empty(options.all) ? '' : 'all',
        \   empty(options.remotes) ? '' : 'remotes',
        \ ],
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let options = gita#option#cascade('^branch$', a:options, {
        \ 'selection': [],
        \})
  let options['quiet'] = 1
  let options['no-column'] = 1
  let options['no-color'] = 1
  let options['no-abbrev'] = 1
  let options['list'] = get(options, 'list', 1)
  let result = gita#command#branch#call(options)
  let branches = s:GitParser.parse_branch(result.content)
  call gita#meta#set('content_type', 'branch')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'selection', 'quiet',
        \]))
  call gita#meta#set('branches', branches)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-branch
  setlocal buftype=nofile nobuflisted
  setlocal nowrap
  setlocal cursorline
  setlocal nomodifiable
  call gita#ui#branch#redraw()
  call gita#util#select(options.selection)
endfunction


function! gita#ui#branch#autocmd(name) abort
  let bufname = expand('<amatch>')
  let options = gita#util#cascade#get('branch')
  let options.all = bufname =~# ':all\%(:\|$\)'
  let options.remotes = bufname =~# ':remotes\%(:\|$\)'
  call call('s:on_' . a:name, [options])
endfunction

function! gita#ui#branch#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#ui#branch#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('branch', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
endfunction

function! gita#ui#branch#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let branches = gita#meta#get_for('branch', 'branches', [])
  let contents = map(copy(branches), 'v:val.record')
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction

call gita#util#define_variables('ui#branch', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-branch-checkout)',
      \ 'secondary_action_mapping': '<Plug>(gita-branch-checkout-track)',
      \ 'disable_default_mappings': 0,
      \})
