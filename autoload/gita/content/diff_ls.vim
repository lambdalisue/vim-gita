let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'commit': '',
        \}, a:options)
  return gita#content#build_bufname('diff-ls', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.cached ? 'cached': 'worktree',
        \   options.commit,
        \ ],
        \})
endfunction

function! s:args_from_options(git, options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  let args = gita#process#args_from_options(options, {
        \ 'ignore-submodules': 1,
        \ 'no-renames': 1,
        \ 'B': 1,
        \ 'find-renames': 1,
        \ 'find-copies': 1,
        \ 'find-copies-harder': 1,
        \ 'text': 1,
        \ 'ignore-space-change': 1,
        \ 'ignore-all-space': 1,
        \ 'ignore-blank-lines': 1,
        \ 'cached': 1,
        \})
  let args = ['diff', '--numstat'] + args + [
        \ gita#normalize#commit_for_diff(a:git, options.commit),
        \]
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
        \], g:gita#content#diff_ls#disable_default_mappings)

  if g:gita#content#diff_ls#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#diff_ls#primary_action_mapping
        \)
endfunction

function! s:get_candidates(startline, endline) abort
  let stats = gita#meta#get_for('^diff-ls$', 'stats', [])
  let records = getline(a:startline, a:endline)
  return gita#action#filter(stats, records, 'record')
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
  let cached = gita#meta#get_for('^diff-ls$', 'cached', 0)
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
    let lhs = cached ? 'INDEX' : 'WORKTREE'
    let rhs = empty(commit) ? (cached ? 'HEAD' : 'INDEX') : commit
  endif
  return printf(
        \ '%d file%s %s different between %s and %s %s',
        \ nstats,
        \ nstats == 1 ? '' : 's',
        \ nstats == 1 ? 'is' : 'are',
        \ lhs, rhs,
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^diff-ls$', a:options)
  let content = s:execute_command(options)
  let stats = s:GitParser.parse_numstat(content)
  let stats = s:extend_stats(stats, winwidth(0))
  call gita#meta#set('content_type', 'diff-ls')
  call gita#meta#set('options', options)
  call gita#meta#set('cached', options.cached)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('stats', stats)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-diff-ls
  setlocal buftype=nofile nobuflisted
  setlocal bufhidden=wipe
  setlocal nomodifiable
  call gita#content#diff_ls#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#diff_ls#open(options) abort
  let options = extend({
        \ 'opener': 'botright 10 split',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  call gita#util#cascade#set('diff-ls', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
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
  let options.cached = get(a:bufinfo.extra_options, 0, '') ==# 'cached'
  let options.commit = get(a:bufinfo.extra_options, 1, '')
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#diff_ls', {
      \ 'primary_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})
