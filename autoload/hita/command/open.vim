let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_worktree_content(hita, commit, filename) abort
  if filereadable(a:filename)
    return readfile(a:filename)
  else
    call hita#throw(printf('%s is not readable.', a:filename))
  endif
endfunction
function! s:get_ancestor_content(hita, commit, filename) abort
  let [lhs, rhs] = matchlist(a:commit, '^\([^.]*\)\.\{3}\([^.]*\)$')[1 : 2]
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let result = hita#operation#exec(a:hita, 'merge_base', {
        \ 'commit1': lhs,
        \ 'commit2': rhs,
        \})
  if result.status
    call hita#throw(printf(
          \ 'A common ancestor of %s and %s could not be found.',
          \ lhs, rhs,
          \))
  endif
  return s:get_revision_content(a:hita, result.stdout, a:filename)
endfunction
function! s:get_revision_content(hita, commit, filename) abort
  "let commit = a:commit ==# 'INDEX' ? '' : a:commit
  let commit = a:commit
  let object = printf('%s:%s', commit,
        \ a:hita.git.get_relative_path(s:Path.unixpath(a:filename))
        \)
  let result = hita#operation#exec(a:hita, 'show', {
        \ 'object': object,
        \})
  if result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n')
endfunction

function! hita#command#open#call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  if hita.fail_on_disabled()
    return [[], options.commit, options.filename]
  endif
  try
    let commit = hita#variable#get_valid_commit(options.commit)
    let filename = hita#variable#get_valid_filename(options.filename)
    if commit ==# 'WORKTREE'
      let content = s:get_worktree_content(hita, commit, filename)
    elseif commit =~# '^[^.]*\.\{3}[^.]*$'
      let content = s:get_ancestor_content(hita, commit, filename)
    elseif commit =~# '^[^.]*\.\{2}[^.]*$'
      let commit = matchstr(commit, '^[^.]*\.\{2}\zs[^.]*$')
      let content = s:get_revision_content(hita, commit, filename)
    else
      let content = s:get_revision_content(hita, commit, filename)
    endif
    return [content, commit, filename]
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return [[], commit, filename]
  endtry
endfunction
function! hita#command#open#read(...) abort
  silent doautocmd FileReadPre
  let options = extend({}, get(a:000, 0, {}))
  let content = hita#command#open#call(options)[0]
  if empty(content)
    return
  endif
  call hita#util#buffer#read_content(content)
  redraw
  silent doautocmd FileReadPost
endfunction
function! hita#command#open#edit(...) abort
  silent doautocmd BufReadPre
  let options = extend({}, get(a:000, 0, {}))
  let [content, commit, filename] = hita#command#open#call(options)
  if empty(content)
    return
  endif
  call hita#meta#set('commit', commit)
  call hita#meta#set('filename', filename)
  call hita#util#buffer#edit_content(content)
  silent doautocmd BufReadPost
endfunction
function! hita#command#open#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:hita#command#open#default_opener
        \ : options.opener
  let bufname = hita#command#open#bufname(options)
  if !empty(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will execute hita#command#open#edit()
  endif
endfunction
function! hita#command#open#bufname(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  try
    let commit = hita#variable#get_valid_commit(options.commit)
    let filename = hita#variable#get_valid_filename(options.filename)
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  if options.commit ==# 'WORKTREE'
    return filename
  else
    return 'hita://' . join([commit, filename], ':')
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita open',
          \ 'description': 'Open a content',
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Force', {
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit',
          \ 'A commit', {
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \})
  endif
  return s:parser
endfunction
function! hita#command#open#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call hita#option#assign_commit(options, '%')
  call hita#option#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#open#default_options),
        \ options,
        \)
  call hita#command#open#open(options)
endfunction
function! hita#command#open#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#define_variables('command#open', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
