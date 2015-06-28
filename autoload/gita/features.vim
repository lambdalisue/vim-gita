let s:save_cpo = &cpo
set cpo&vim


" Modules
let s:P = gita#utils#import('Prelude')
let s:A = gita#utils#import('ArgumentParser')


let s:feature_registry = {}
let s:feature_pattern = '^$'

function! s:is_registered(name) abort " {{{
  return a:name =~# s:feature_pattern
endfunction " }}}
function! s:register(name, command, complete) abort " {{{
  if s:is_registered(a:name) && !get(g:, 'gita#debug', 0)
    throw printf(
          \ 'vim-gita: a feature "%s" has already been registered.',
          \ a:name,
          \)
  endif
  let s:feature_registry[a:name] = {
        \ 'command': a:command,
        \ 'complete': a:complete
        \}
  let s:feature_pattern = printf('^\%%(%s\)$',
        \ join(keys(s:feature_registry), '\|'),
        \)
endfunction " }}}
function! s:unregister(name, callback) abort " {{{
  if !s:is_registered(a:name)
    throw printf(
          \ 'vim-gita: a feature "%s" has not been registered.',
          \ a:name,
          \)
  endif
  unlet! s:feature_registry[a:name]
  let s:feature_pattern = printf('^\%%(%s\)$',
        \ join(keys(s:feature_registry), '\|'),
        \)
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'An altimate git interface of Vim',
          \})
    call s:parser.add_argument(
          \ 'action',
          \ 'An action of the Gita command', {
          \   'terminal': 1,
          \ })
  endif
  return s:parser
endfunction " }}}
function! s:parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let parser = s:get_parser()
  return parser.parse(a:bang, a:range, cmdline)
endfunction " }}}


function! gita#features#is_registered(...) abort " {{{
  call call('s:is_registered', a:000)
endfunction " }}}
function! gita#features#register(...) abort " {{{
  call call('s:register', a:000)
endfunction " }}}
function! gita#features#unregister(...) abort " {{{
  call call('s:unregister', a:000)
endfunction " }}}
function! gita#features#command(bang, range, ...) abort " {{{
  let opts = s:parse(a:bang, a:range, get(a:000, 0, ''))
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !s:is_registered(name)
    " execute git command
    let gita = gita#core#get()
    let result = gita.operations.exec_raw(opts.__args__)
    if result.status == 0
      call gita#utils#info(
            \ printf('Ok: "%s"', join(result.args)),
            \)
      call gita#utils#info(result.stdout)
    endif
  else
    " execute Gita command
    let feature = s:feature_registry[name]
    let args = [a:bang, a:range, join(opts.__unknown__)]
    call call(feature.command, args)
  endif
endfunction " }}}
function! gita#features#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\v^Gita!?\s?', '', '')
  let opts = s:parse(bang, [0, 0], cmdline)
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !s:is_registered(name)
    let candidates = keys(s:feature_registry)
    call filter(candidates, printf('v:val =~# "^%s"', a:arglead))
  else
    " execute Gita command
    let feature = s:feature_registry[name]
    let cmdline = printf('%s %s', name, join(opts.__unknown__))
    let cmdline = join(opts.__unknown__)
    let args = [a:arglead, cmdline, a:cursorpos]
    let candidates = call(feature.complete, args)
  endif
  return candidates
endfunction " }}}

" Register features
call s:register('add',
      \ function('gita#features#add#command'),
      \ function('gita#features#add#complete'),
      \)
call s:register('rm',
      \ function('gita#features#rm#command'),
      \ function('gita#features#rm#complete'),
      \)
call s:register('reset',
      \ function('gita#features#reset#command'),
      \ function('gita#features#reset#complete'),
      \)
call s:register('checkout',
      \ function('gita#features#checkout#command'),
      \ function('gita#features#checkout#complete'),
      \)

call s:register('file',
      \ function('gita#features#file#command'),
      \ function('gita#features#file#complete'),
      \)
call s:register('diff',
      \ function('gita#features#diff#command'),
      \ function('gita#features#diff#complete'),
      \)
call s:register('browse',
      \ function('gita#features#browse#command'),
      \ function('gita#features#browse#complete'),
      \)

call s:register('status',
      \ function('gita#features#status#command'),
      \ function('gita#features#status#complete'),
      \)
call s:register('commit',
      \ function('gita#features#commit#command'),
      \ function('gita#features#commit#complete'),
      \)
call s:register('diff-ls',
      \ function('gita#features#diff_ls#command'),
      \ function('gita#features#diff_ls#complete'),
      \)

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
