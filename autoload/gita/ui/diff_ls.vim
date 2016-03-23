let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')
let s:candidate_offset = 0

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let stats = gita#meta#get_for('diff-ls', 'stats', [])
  return index >= 0 ? get(stats, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#ui#diff_ls#disable_default_mappings)
  if g:gita#ui#diff_ls#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#ui#diff_ls#primary_action_mapping
        \)
endfunction

function! s:get_header_string(git) abort
  let commit = gita#meta#get('commit', '')
  let stats = gita#meta#get('stats', [])
  let nstats = len(stats)
  if commit =~# '^.\{-}\.\.\..\{-}$'
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let lhs = commit
  elseif commit =~# '^.\{-}\.\..\{-}$'
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
  else
    let lhs = 'WORKTREE'
    let rhs = empty(commit) ? 'INDEX' : commit
  endif
  return printf(
        \ 'File differences between <%s> and <%s> (%d file%s %s different) %s',
        \ lhs, rhs, nstats,
        \ nstats == 1 ? '' : 's',
        \ nstats == 1 ? 'is' : 'are',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:extend_stat(git, commit, stat) abort
  let a:stat.relpath = a:stat.path
  let a:stat.path = s:Path.realpath(
        \ s:Git.get_absolute_path(a:git, a:stat.path),
        \)
  let a:stat.commit = a:commit
  return a:stat
endfunction

function! s:format_stat(stat, alpha, format) abort
  let added   = repeat('+', float2nr(a:stat.added * a:alpha))
  let deleted = repeat('-', float2nr(a:stat.deleted * a:alpha))
  let status = printf(a:format,
        \ a:stat.relpath,
        \ a:stat.added,
        \ a:stat.deleted,
        \ added . deleted,
        \)
  return status
endfunction

function! s:format_stats(stats, width) abort
  let max_path    = 0
  let max_added   = 0
  let max_deleted = 0
  for stat in a:stats
    if len(stat.relpath) > max_path
      let max_path = len(stat.relpath)
    endif
    if stat.added > max_added 
      let max_added = stat.added
    endif
    if stat.deleted > max_deleted
      let max_deleted = stat.deleted
    endif
  endfor
  " e.g.
  " autoload/gita.vim         35  0 +++++++++.............
  " autoload/gita/status.vim 100 30 +++++++++++++---------
  let format = printf(
        \ '%%-%ds +%%-%dd -%%-%dd %%s',
        \ max_path, len(max_added) + 1, len(max_deleted) + 1,
        \)
  let guide_width = a:width - len(printf(format, '0', 0, 0, ''))
  let alpha = guide_width / str2float(max([max_added, max_deleted]) * 2)
  let content = map(copy(a:stats),
        \ 's:format_stat(v:val, alpha, format)'
        \)
  return content
endfunction

function! s:get_bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(git, options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'diff-ls',
        \ 'extra_option': [
        \   commit,
        \ ],
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^diff-ls$', a:options, {
        \ 'selection': [],
        \})
  let options['quiet'] = 1
  let options['numstat'] = 1
  let result = gita#command#diff#call(options)
  let stats = s:GitParser.parse_numstat(result.content)
  call map(stats, 's:extend_stat(git, result.commit, v:val)')
  call gita#meta#set('content_type', 'diff-ls')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('stats', stats)
  call gita#meta#set('winwidth', winwidth(0))
  augroup vim_gita_internal_diff_ls
    autocmd! * <buffer>
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal nolist
  setlocal filetype=gita-diff-ls
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#ui#diff_ls#redraw()
  call gita#util#select(options.selection)
endfunction

function! s:on_VimResized() abort
  try
    if gita#meta#get_for('diff_ls', 'winwidth', winwidth(0)) != winwidth(0)
      call gita#ui#diff_ls#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! s:on_WinEnter() abort
  try
    if gita#meta#get_for('diff_ls', 'winwidth', winwidth(0)) != winwidth(0)
      call gita#command#diff_ls#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction


function! gita#ui#diff_ls#autocmd(name) abort
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
  let options.commit = gita#variable#get_valid_range(git, m[1], {
        \ '_allow_empty': 1,
        \})
  call call('s:on_' . a:name, [options])
endfunction

function! gita#ui#diff_ls#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#ui#diff_ls#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('diff-ls', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
endfunction

function! gita#ui#diff_ls#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let stats = gita#meta#get_for('diff-ls', 'stats', [])
  let contents = s:format_stats(stats, winwidth(0))
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction


call gita#util#define_variables('ui#diff_ls', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})