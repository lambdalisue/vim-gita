let s:save_cpo = &cpo
set cpo&vim


" Modules
let s:L = gita#utils#import('Data.List')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita diff',
          \ 'description': 'Show or compare a difference of a file in Gita interface',
          \})
    call s:parser.add_argument(
          \ 'commit',
          \ 'A commit string to specify how to compare the versions', {
          \   'required': 1,
          \ })
    call s:parser.add_argument(
          \ '--diff', '-d',
          \ 'Open 2-way diff to compare the difference', {
          \   'conflicts': ['open'],
          \ })
    call s:parser.add_argument(
          \ '--open', '-o',
          \ 'Open a diff format buffer to show the difference', {
          \   'conflicts': ['diff'],
          \ })

    function! s:parser.hooks.pre_validation(opts) abort
      " Automatically use '--open' if no conflicted argument is specified
      if empty(self.get_conflicted_arguments('open', a:opts))
        let a:opts.open = 1
      endif
    endfunction
  endif
  return s:parser
endfunction " }}}

function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:smart_redraw() abort " {{{
  if &diff
    diffupdate | redraw!
  else
    redraw!
  endif
endfunction " }}}

function! s:open(path, commit, ...) abort " {{{
  let gita = s:get_gita(a:path)
  let options = extend({}, get(a:000, 0, {}))

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#diff#s:open',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', gita),
          \)
    return
  endif

  let path = gita.git.get_absolute_path(a:path)
  let args = filter([
        \ 'diff',
        \ '--no-prefix',
        \ '--no-color',
        \ '--unified=0',
        \ '--histogram',
        \ a:commit,
        \ '--',
        \ path,
        \], '!empty(v:val)')
  let result = gita.exec(args)
  if result.status != 0
    return
  endif

  let DIFF = split(result.stdout, '\v\r?\n')
  let DIFF_bufname = gita#utils#buffer#bufname(
        \ printf('%s.diff', path),
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \)
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(path, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(DIFF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
endfunction " }}}
function! s:diff(path, commit, ...) abort " {{{
  let gita = s:get_gita(a:path)
  let options = get(a:000, 0, {})

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#diff#s:diff',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', gita),
          \)
    return
  endif

  let path = gita.git.get_relative_path(a:path)
  let args = s:L.flatten([
        \ 'show',
        \ printf('%s:%s', a:commit, path),
        \])
  let result = gita.exec(args)
  if result.status != 0
    return
  endif

  let REF = split(result.stdout, '\v\r?\n')
  let REF_bufname = gita#utils#buffer#bufname(
        \ path,
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \)
  let opener = get(options, 'opener', 'edit')

  " LOCAL
  call gita#utils#buffer#open(path, 'diff_LOCAL', {
        \ 'opener': opener,
        \})
  let LOCAL_bufnum = bufnr('%')
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  diffthis

  " REFERENCE
  if gita#utils#buffer#is_listed_in_tabpage(REF_bufname)
    let opener = 'edit'
  else
    let opener = get(options, 'vertical') ? 'vert split' : 'split'
  endif
  call gita#utils#buffer#open(REF_bufname, 'diff_REF', {
        \ 'opener': opener,
        \})
  let REF_bufnum = bufnr('%')
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  call gita#utils#buffer#update(REF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
  diffthis

  diffupdate
endfunction " }}}
function! s:ac_buf_win_leave() abort " {{{
  diffoff
  augroup vim-gita-diff
    autocmd! * <buffer>
  augroup END
endfunction " }}}


" Internal API
function! gita#features#diff#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#diff#diff(...) abort " {{{
  call call('s:diff', a:000)
endfunction " }}}


" External API
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if get(opts, 'open', 0)
    call s:open(expand('%'), opts.commit, opts)
  elseif get(opts, 'diff', 0)
    call s:diff(expand('%'), opts.commit, opts)
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
