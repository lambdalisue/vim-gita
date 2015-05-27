let s:save_cpo = &cpo
set cpo&vim


" Modules
let s:P = gita#utils#import('Prelude')
let s:A = gita#utils#import('ArgumentParser')


let s:command_registry = {}
let s:command_pattern = '^$'

function! s:is_registered(name) abort " {{{
  return a:name =~# s:command_pattern
endfunction " }}}
function! s:register(name, callbacks) abort " {{{
  if s:is_registered(a:name)
    throw printf(
          \ 'vim-gita: a command "%s" has already been registered.',
          \ a:name,
          \)
  endif
  if s:P.is_string(callbacks)
    let callbacks = {
          \ 'parse':  function(printf('%s#run', a:callbacks)),
          \ 'parse':  function(printf('%s#run', a:callbacks)),
          \ 'complete': function(printf('%s#complete', a:callbacks)),
          \}
  else
    let callbacks = deepcopy(a:callbacks)
  endif
  let s:command_registry[a:name] = callbacks
  let s:command_pattern = printf('^\%%(%s\)$',
        \ join(keys(s:command_registry), '\|'),
        \)
endfunction " }}}
function! s:unregister(name, callback) abort " {{{
  if !s:is_registered(a:name)
    throw printf(
          \ 'vim-gita: a command "%s" has not been registered.',
          \ a:name,
          \)
  endif
  unlet! s:command_registry[a:name]
  let s:command_pattern = printf('^\%%(%s\)$',
        \ join(keys(s:command_registry), '\|'),
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
function! gita#features#run(bang, range, ...) abort " {{{
  let opts = s:parse(a:bang, a:range, get(a:000, 0, ''))
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !s:is_registered(name)
    " execute git command
    let gita = gita#core#get()
    let result = gita.git.exec(opts.__args__)
    if result.status == 0
      call gita#utils#info(
            \ printf('Ok: "%s"', join(result.args)),
            \)
      call gita#utils#info(result.stdout)
      call gita#utils#doautocmd(printf('%s-post', name))
    else
      call gita#utils#warn(
            \ printf('Fail: "%s"', join(result.args)),
            \)
      call gita#utils#info(result.stdout)
    endif
  else
    " execute Gita command
    let callbacks = s:command_registry[name]
    let args = [a:bang, a:range, join(opts.__unknown__)]
    call call(callbacks.run, args)
  endif
endfunction " }}}
function! gita#features#complete(bang, range, ...) abort " {{{
  let opts = s:parse(a:bang, a:range, get(a:000, 0, ''))
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !s:is_registered(name)
    " execute git command
    let gita = gita#core#get()
    let result = gita.git.exec(opts.__args__)
    if result.status == 0
      call gita#utils#info(
            \ printf('Ok: "%s"', join(result.args)),
            \)
      call gita#utils#info(result.stdout)
      call gita#utils#doautocmd(printf('%s-post', name))
    else
      call gita#utils#warn(
            \ printf('Fail: "%s"', join(result.args)),
            \)
      call gita#utils#info(result.stdout)
    endif
  else
    " execute Gita command
    call call(
          \ s:command_registry[name],
          \ [a:bang, a:range, join(opts.__unknown__)])
  endif
endfunction " }}}


" Register features
call s:register('status', [
      \ function('gita#features#status#command'),
      \ function('gita#features#status#complete'),
      \])
call s:register('commit', 'gita#features#commit')
call s:register('difflist', 'gita#features#difflist')

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
