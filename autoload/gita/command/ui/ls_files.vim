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
        \], g:gita#command#ui#ls_files#disable_default_mappings)
  if g:gita#command#ui#ls_files#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#ls_files#primary_action_mapping
        \)
endfunction

function! s:extend_filename(git, filename) abort
  let candidate = {}
  let candidate.relpath = a:filename
  let candidate.path = s:Git.get_absolute_path(
        \ a:git, s:Path.realpath(a:filename),
        \)
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
        \}, a:options)
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'ls-files',
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^ls-files$', a:options, {
        \ 'selection': [],
        \})
  let options['full-name'] = 1
  let options['quiet'] = 1
  let result = gita#command#ls_files#call(options)
  let candidates = map(
        \ copy(result.content),
        \ 's:extend_filename(git, v:val)'
        \)
  call gita#meta#set('content_type', 'ls-files')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'selection', 'quiet', 'full-name',
        \]))
  call gita#meta#set('candidates', candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-files
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ui#ls_files#redraw()
  call gita#util#select(options.selection)
endfunction


function! gita#command#ui#ls_files#autocmd(name) abort
  let options = gita#util#cascade#get('ls-files')
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#ls_files#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#ls_files#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('ls-files', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
endfunction

function! gita#command#ui#ls_files#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let candidates = gita#meta#get_for('ls-files', 'candidates', [])
  let contents = map(copy(candidates), 'v:val.relpath')
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction


call gita#util#define_variables('command#ui#ls_files', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})

