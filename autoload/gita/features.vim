let s:save_cpo = &cpo
set cpo&vim


" Modules
let s:P = gita#utils#import('Prelude')
let s:A = gita#utils#import('ArgumentParser')


let s:feature_registry = {}
let s:feature_pattern = '^$'


function! s:complete_action(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita_features = keys(s:feature_registry)
  let git_features = [
        \ 'push', 'pull', 'submodule', 'remote',
        \]
  return extend(gita_features, git_features)
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!]',
      \ 'description': 'An altimate git interface of Vim',
      \})
call s:parser.add_argument(
      \ 'action', [
      \   'An action of the Gita or git command.',
      \   'If non Gita command is specified or a command is called with a bang (!)',
      \   'it call raw git command instead of Gita command.',
      \ ], {
      \   'terminal': 1,
      \   'complete': function('s:complete_action'),
      \ })


function! gita#features#is_registered(name) abort " {{{
  return a:name =~# s:feature_pattern
endfunction " }}}
function! gita#features#register(name, command, complete) abort " {{{
  if gita#features#is_registered(a:name) && !g:gita#debug
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
function! gita#features#unregister(name) abort " {{{
  if !gita#features#is_registered(a:name)
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
function! gita#features#command(bang, range, ...) abort " {{{
  let opts = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(opts)
    let name = get(opts, 'action', 'help')
    if opts.__bang__ || !gita#features#is_registered(name)
      " execute git command
      let gita = gita#get()
      let args = map(opts.__args__, 'gita#utils#expand(v:val)')
      call gita.operations.exec_raw(args)
    else
      " execute Gita command
      let feature = s:feature_registry[name]
      let args = [a:bang, a:range, join(opts.__unknown__)]
      call call(feature.command, args)
    endif
  endif
endfunction " }}}
function! gita#features#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\v^Gita!?\s?', '', '')
  let opts = s:parser.parse(bang, [0, 0], cmdline)
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !gita#features#is_registered(name)
    let candidates = s:parser.complete(a:arglead, a:cmdline, a:cursorpos, opts)
  else
    " execute Gita command
    let feature = s:feature_registry[name]
    let cmdline = printf('%s %s', name, join(opts.__unknown__))
    let args = [a:arglead, cmdline, a:cursorpos]
    let candidates = call(feature.complete, args)
  endif
  return candidates
endfunction " }}}


" Register features
call gita#features#register('add',
      \ function('gita#features#add#command'),
      \ function('gita#features#add#complete'),
      \)
call gita#features#register('rm',
      \ function('gita#features#rm#command'),
      \ function('gita#features#rm#complete'),
      \)
call gita#features#register('reset',
      \ function('gita#features#reset#command'),
      \ function('gita#features#reset#complete'),
      \)
call gita#features#register('checkout',
      \ function('gita#features#checkout#command'),
      \ function('gita#features#checkout#complete'),
      \)

call gita#features#register('file',
      \ function('gita#features#file#command'),
      \ function('gita#features#file#complete'),
      \)
call gita#features#register('diff',
      \ function('gita#features#diff#command'),
      \ function('gita#features#diff#complete'),
      \)
call gita#features#register('conflict',
      \ function('gita#features#conflict#command'),
      \ function('gita#features#conflict#complete'),
      \)
call gita#features#register('browse',
      \ function('gita#features#browse#command'),
      \ function('gita#features#browse#complete'),
      \)

call gita#features#register('status',
      \ function('gita#features#status#command'),
      \ function('gita#features#status#complete'),
      \)
call gita#features#register('commit',
      \ function('gita#features#commit#command'),
      \ function('gita#features#commit#complete'),
      \)
call gita#features#register('diff-ls',
      \ function('gita#features#diff_ls#command'),
      \ function('gita#features#diff_ls#complete'),
      \)

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
