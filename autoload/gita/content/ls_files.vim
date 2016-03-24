let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')

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

function! s:execute_command(options) abort
  let args = gita#util#args_from_options(a:options, {
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
        \] + args
  let args += ['--'] + a:options.filenames
  return gita#command#execute(args, { 'quiet': 1 })
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
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
  execute printf(
        \ 'nmap <buffer> <S-Return> %s',
        \ g:gita#content#ls_files#secondary_action_mapping
        \)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let candidates = gita#meta#get_for('^ls-files$', 'candidates', [])
  return gita#action#find_candidate(candidates, record, 'path')
endfunction

function! s:extend_filename(filename) abort
  return { 'path': a:filename }
endfunction

function! s:get_prologue(git) abort
  let commit = gita#meta#get_for('^ls-files$', 'commit', '')
  let candidates = gita#meta#get_for('^ls-files$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files in <%s> (%d file%s) %s',
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? or <Tab> to show help or do action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^ls-files$', a:options, {
        \ 'filenames': [],
        \})
  let content = s:execute_command(options)
  let candidates = map(content, 's:extend_filename(v:val)')
  call gita#meta#set('content_type', 'ls-files')
  call gita#meta#set('options', options)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-files
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#ls_files#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#ls_files#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#ls_files#default_opener
        \ : options.opener
  call gita#util#cascade#set('ls-files', s:Dict.pick(options, [
        \ 'filenames',
        \ 'cached',
        \ 'deleted',
        \ 'modified',
        \ 'others',
        \ 'ignored',
        \ 'stage',
        \ 'directory',
        \ 'no-empty-directory',
        \ 'unmerged',
        \ 'killed',
        \ 'exclude-standard',
        \ 'error-unmatch',
        \ 'full-name',
        \ 'abbrev',
        \ 'exclude',
        \ 'exclude-from',
        \ 'exclude-per-directory',
        \ 'with-tree',
        \]))
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
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

call gita#util#define_variables('content#ls_files', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'secondary_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})
