let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


function! s:ensure_revision(options, default) abort " {{{
  if !has_key(a:options, 'revision') || get(a:options, 'new')
    let revision = gita#utils#ask(
          \ 'Which revision do you want to compare with? ',
          \ get(a:options, 'revision', a:default),
          \)
    if empty(revision)
      call gita#utils#info('Operation has canceled by user')
      return 0
    endif
  else
    let revision = a:options.revision
  endif
  " Note:
  "   A value of 'revision' might contains leading/trailing dots
  "   like 'master...' or '..master' or whatever
  let revision = substitute(revision, '\%(^\.\+\|\.\+$\)', '', 'g')
  let revision = substitute(revision, '^INDEX$', '', '')
  let a:options.revision = revision
  return 1
endfunction " }}}


let s:parser = s:A.new({
      \ 'name': 'Gita show',
      \ 'description': [
      \   'Show a file content of a specified revision.',
      \   'Note that it is a limited version of "git show".',
      \ ],
      \})
call s:parser.add_argument(
      \ '--opener', '-o', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \ 'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ 'revision', [
      \   'A revison (e.g. HEAD@{4}) which you want to check.',
      \   'If it is omitted, a prompt shows up to ask which.',
      \ ], {
      \   'complete': function('gita#completes#complete_local_branch'),
      \})
call s:parser.add_argument(
      \ 'file', [
      \   'A filepath which you want to see the content.',
      \   'If it is omitted and the current buffer is a file',
      \   'buffer, the current buffer will be used.',
      \ ],
      \)


function! gita#features#show#_ensure_revision(...) abort " {{{
  return call('s:ensure_revision', a:000)
endfunction " }}}
function! gita#features#show#exec(...) abort " {{{
  let gita = gita#core#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  " automatically specify the current buffer if nothing is specified
  " and the buffer is a file buffer
  if empty(get(options, 'file', ''))
    if !empty(&buftype)
      call gita#utils#error(
            \ 'The current buffer is not a file buffer.',
            \)
      call gita#utils#info(
            \ 'Operation has canceled.'
            \)
      return { 'status': -1 }
    endif
    let options.file = '%'
  endif
  let options.file = expand(options.file)
  let options.file = gita.git.get_relative_path(options.file)
  " Ask if no revision is specified.
  if !s:ensure_revision(options, 'HEAD')
    return
  endif
  let options = {
        \ 'object': printf('%s:%s',
        \   options.revision,
        \   options.file,
        \ ),
        \}
  return gita.operations.show(options, config)
endfunction " }}}
function! gita#features#show#show(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = extend({
        \ 'echo': 'fail',
        \}, get(a:000, 1, {}))
  let result = gita#features#show#exec(options, config)
  if result.status != 0
    return
  endif

  let REF = split(result.stdout, '\v\r?\n')
  let REF_bufname = gita#utils#buffer#bufname(
        \ options.file,
        \ empty(options.revision) ? 'INDEX' : options.revision,
        \)
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(REF_bufname, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(REF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
endfunction " }}}
function! gita#features#show#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#show#show(options)
  endif
endfunction " }}}
function! gita#features#show#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
