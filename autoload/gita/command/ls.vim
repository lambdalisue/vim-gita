let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Guard = s:V.import('Vim.Guard')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [])
  return options
endfunction
function! s:get_ls_files_content(git, commit, directories, options) abort
  let options = s:pick_available_options(a:options)
  let options['full-name'] = 1
  if !empty(a:directories)
    let options['--'] = a:directories
  endif
  let result = gita#execute(a:git, 'ls-files', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:get_ls_tree_content(git, commit, directories, options) abort
  let options = s:pick_available_options(a:options)
  let options['full-name'] = 1
  let options['name-only'] = 1
  let options['r'] = 1
  let options['commit'] = a:commit
  if !empty(a:directories)
    let options['--'] = a:directories
  endif
  let result = gita#execute(a:git, 'ls-tree', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
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
function! s:format_entry(entry) abort
  return a:entry.relpath
endfunction
function! s:get_header_string(git) abort
  let commit = gita#get_meta('commit', '')
  let candidates = gita#get_meta('candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files in <%s> (%d file%s) %s',
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let candidates = gita#get_meta('candidates', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction
function! s:define_actions() abort
  call gita#action#attach(function('s:get_entry'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#command#ls#disable_default_mappings)
  if g:gita#command#ls#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ls#default_action_mapping
        \)
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#ls#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#ls#bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \}, a:options)
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'ls',
        \ 'extra_options': [
        \ ],
        \ 'commitish': commit,
        \ 'path': '',
        \})
endfunction
function! gita#command#ls#call(...) abort
  let options = gita#option#cascade('^ls$', get(a:000, 0, {}), {
        \ 'commit': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(commit)
    let content = s:get_ls_files_content(git, commit, [], options)
  else
    if commit =~# '^.\{-}\.\.\..\{-}$'
      let [lhs, rhs] = s:GitTerm.split_range(commit)
      let lhs = empty(lhs) ? 'HEAD' : lhs
      let rhs = empty(rhs) ? 'HEAD' : rhs
      let _commit = s:GitInfo.find_common_ancestor(git, lhs, rhs)
      let content = s:get_ls_tree_content(git, _commit, [], options)
    elseif commit =~# '^.\{-}\.\..\{-}$'
      let _commit  = s:GitTerm.split_range(commit)[0]
      let content = s:get_ls_tree_content(git, _commit, [], options)
    else
      let content = s:get_ls_tree_content(git, commit, [], options)
    endif
  endif
  let candidates = map(
        \ copy(content),
        \ 's:extend_filename(git, commit, v:val)'
        \)
  let result = {
        \ 'commit': commit,
        \ 'content': content,
        \ 'candidates': candidates,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#ls#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#ls#default_opener
        \ : options.opener
  let bufname = gita#command#ls#bufname(options)
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore+=BufReadCmd
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': 'manipulation_panel',
          \})
  finally
    call guard.restore()
  endtry
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#ls#edit(options)
endfunction
function! gita#command#ls#edit(...) abort
  let options = gita#option#cascade('^ls$', {}, get(a:000, 0, {}))
  let result = gita#command#ls#call(options)
  call gita#set_meta('content_type', 'ls')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener',
        \]))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('candidates', result.candidates)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_ls
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ls#redraw()
endfunction
function! gita#command#ls#redraw() abort
  let git = gita#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let candidates = gita#get_meta('candidates', [])
  let contents = map(
        \ copy(candidates),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita ls',
          \ 'description': 'Show filenames in <INDEX> or a particular commit',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to ls.',
          \   'If nothing is specified, it ls a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it ls a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it ls a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it ls a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! gita#command#ls#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#ls#default_options),
        \ options,
        \)
  call gita#command#ls#open(options)
endfunction
function! gita#command#ls#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#ls#define_highlights() abort
  highlight default link GitaComment    Comment
endfunction
function! gita#command#ls#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
endfunction

call gita#util#define_variables('command#ls', {
      \ 'default_options': {},
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'disable_default_mappings': 0,
      \})
