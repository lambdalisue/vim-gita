let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:candidate_offset = 0

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let candidates = gita#meta#get('candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#ui#ls_tree#disable_default_mappings)
  if g:gita#ui#ls_tree#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#ui#ls_tree#primary_action_mapping
        \)
endfunction

function! s:extend_filename(git, commit, filename) abort
  let candidate = {}
  let candidate.relpath = a:filename
  let candidate.path = s:Git.get_absolute_path(
        \ a:git, s:Path.realpath(a:filename),
        \)
  let candidate.commit = a:commit
  return candidate
endfunction

function! s:get_header_string(git) abort
  let commit = gita#meta#get('commit', '')
  let candidates = gita#meta#get('candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files in <%s> (%d file%s) %s',
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(git, options.commit)
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'ls-tree',
        \ 'extra_option': [
        \   commit,
        \ ],
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^ls-tree$', a:options, {
        \ 'selection': [],
        \})
  let options['full-name'] = 1
  let options['name-only'] = 1
  let options['r'] = 1
  let options['quiet'] = 1
  let result = gita#command#ls_tree#call(options)
  let candidates = map(
        \ copy(result.content),
        \ 's:extend_filename(git, result.commit, v:val)'
        \)
  call gita#meta#set('content_type', 'ls-tree')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'opener', 'selection', 'quiet',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('candidates', candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-tree
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#ui#ls_tree#redraw()
  call gita#util#select(options.selection)
endfunction


function! gita#ui#ls_tree#autocmd(name) abort
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita:[^:\\/]\+:diff-ls:\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ expand('<afile>'),
          \))
  endif
  let git = gita#core#get_or_fail()
  let options = gita#util#cascade#get('diff-ls')
  let options.commit = gita#variable#get_valid_range(git, m[1])
  call call('s:on_' . a:name, [options])
endfunction

function! gita#ui#ls_tree#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#ui#ls_tree#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('ls-tree', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
endfunction

function! gita#ui#ls_tree#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let candidates = gita#meta#get_for('ls-tree', 'candidates', [])
  let contents = map(copy(candidates), 'v:val.relpath')
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction


call gita#util#define_variables('ui#ls_tree', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})
