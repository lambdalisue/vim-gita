let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  return gita#content#build_bufname('diff-ls', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.commit,
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = [
        \ 'diff',
        \ '--numstat',
        \ a:options.commit,
        \]
  let git = gita#core#get_or_fail()
  return gita#process#execute(git, args, { 'quiet': 1 })
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#content#diff_ls#disable_default_mappings)

  if g:gita#content#diff_ls#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#diff_ls#primary_action_mapping
        \)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let stats = gita#meta#get_for('^diff-ls$', 'stats', [])
  return gita#action#find_candidate(stats, record, 'record')
endfunction

function! s:extend_stats(stats, width) abort
  let max_path    = 0
  let max_added   = 0
  let max_deleted = 0
  for stat in a:stats
    if len(stat.path) > max_path
      let max_path = len(stat.path)
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
  return map(copy(a:stats),
        \ 'extend(v:val, { ''record'': s:format_stat(v:val, alpha, format) })'
        \)
endfunction

function! s:format_stat(stat, alpha, format) abort
  let added   = repeat('+', float2nr(a:stat.added * a:alpha))
  let deleted = repeat('-', float2nr(a:stat.deleted * a:alpha))
  return printf(a:format,
        \ a:stat.path,
        \ a:stat.added,
        \ a:stat.deleted,
        \ added . deleted,
        \)
endfunction

function! s:get_prologue(git) abort
  let commit = gita#meta#get_for('^diff-ls$', 'commit', '')
  let stats = gita#meta#get_for('^diff-ls$', 'stats', [])
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
        \ '| Press ? or <Tab> to show help or do action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^diff-ls$', a:options, {
        \ 'commit': '',
        \})
  let content = s:execute_command(options)
  let stats = s:GitParser.parse_numstat(content)
  let stats = s:extend_stats(stats, winwidth(0))
  call gita#meta#set('content_type', 'diff-ls')
  call gita#meta#set('options', options)
  call gita#meta#set('stats', stats)
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-diff-ls
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#diff_ls#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#diff_ls#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#diff_ls#default_opener
        \ : options.opener
  call gita#util#cascade#set('diff-ls', s:Dict.pick(options, [
        \ 'commit',
        \]))
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#diff_ls#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^diff-ls$', 'stats', [])),
        \ 'v:val.record',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#diff_ls#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('diff-ls')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#diff_ls', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})

