let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')

function! s:get_header_string(git) abort
  let commit = gita#get_meta('commit', '')
  let stats = gita#get_meta('stats', [])
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

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let stats = gita#get_meta('stats', [])
  return index >= 0 ? get(stats, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#diff_ls#edit()
  endfunction

  call gita#action#includes(
        \ g:gita#command#diff_ls#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'add', 'rm', 'reset', 'checkout',
        \   'stage', 'unstage', 'toggle', 'discard',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \   'commit',
        \])

  if g:gita#command#diff_ls#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#diff_ls#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#diff_ls#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_VimResized() abort
  try
    if gita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call gita#command#diff_ls#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_WinEnter() abort
  try
    if gita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call gita#command#diff_ls#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_GitaStatusModified() abort
  try
    let winnum = winnr()
    keepjump windo
          \ if &filetype ==# 'gita-diff-ls' |
          \   call gita#command#diff_ls#edit() |
          \ endif
    execute printf('keepjump %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#diff_ls#bufname(...) abort
  let options = gita#option#init('^diff-ls$', get(a:000, 0, {}), {
        \ 'commit': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'diff-ls',
        \ 'extra_options': [
        \ ],
        \ 'commitish': commit,
        \ 'path': '',
        \})
endfunction
function! gita#command#diff_ls#call(...) abort
  let options = gita#option#init('^diff-ls$', get(a:000, 0, {}), {
        \ 'commit': '',
        \})
  let git = gita#get_or_fail()
  let options['numstat'] = 1
  let result = gita#command#diff#call(options)
  let stats = s:GitParser.parse_numstat(result.content)
  call map(stats, 's:extend_stat(git, result.commit, v:val)')
  let result = {
        \ 'options': options,
        \ 'commit': result.commit,
        \ 'content': result.content,
        \ 'stats': stats,
        \}
  return result
endfunction
function! gita#command#diff_ls#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#diff_ls#default_opener
        \ : options.opener
  let bufname = gita#command#diff_ls#bufname(options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'manipulation_panel',
        \})
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#diff_ls#edit(options)
endfunction
function! gita#command#diff_ls#edit(...) abort
  let options = get(a:000, 0, {})
  let result = gita#command#diff_ls#call(options)
  call gita#set_meta('content_type', 'diff-ls')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('stats', result.stats)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_diff_ls
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  " the following options are required so overwrite everytime
  setlocal nolist
  setlocal filetype=gita-diff-ls
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  if exists('#BufReadPre')
    doautocmd BufReadPre
  endif
  call gita#command#diff_ls#redraw()
  if exists('#BufReadPost')
    doautocmd BufReadPost
  endif
endfunction
function! gita#command#diff_ls#redraw() abort
  let git = gita#get_or_fail()
  let prologue = s:List.flatten([
        \ [s:get_header_string(git)],
        \ gita#action#mapping#get_visibility()
        \   ? map(gita#action#get_mapping_help(), '"| " . v:val')
        \   : []
        \])
  let stats = gita#get_meta('stats', [])
  let contents = s:format_stats(stats, winwidth(0))
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita diff-ls',
          \ 'description': 'Show a diff content of a commit or files',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to diff.',
          \   'If nothing is specified, it diff a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it diff a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it diff a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it diff a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#diff_ls#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#diff_ls#default_options),
        \ options,
        \)
  call gita#command#diff_ls#open(options)
endfunction
function! gita#command#diff_ls#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#diff_ls#define_highlights() abort
  highlight default link GitaComment Comment
  highlight default link GitaAdded   Special
  highlight default link GitaDeleted Constant
  highlight default link GitaDiffZero Comment
endfunction
function! gita#command#diff_ls#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
  syntax match GitaDiffLs        /^.\{-} +\d\+\s\+-\d\+\s\++*-*$/
        \ contains=GitaDiffLsSuffix
  syntax match GitaDiffLsSuffix  /+\d\+\s\+-\d\+\s\++*-*$/
        \ contains=GitaAdded,GitaDeleted,GitaDiffZero
  syntax match GitaAdded   /+[0-9+]*/ contained
  syntax match GitaDeleted /-[0-9-]*/ contained
  syntax match GitaDiffZero /[+-]0/ contained
endfunction

call gita#util#define_variables('command#diff_ls', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-edit)',
      \ 'enable_default_mappings': 1,
      \})
