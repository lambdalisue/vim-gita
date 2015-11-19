let s:save_cpoptions = &cpoptions
set cpoptions&vim


" Modules
let s:P = gita#import('Prelude')
let s:L = gita#import('Data.List')
let s:A = gita#import('ArgumentParser')


let s:feature_registry = {}
let s:feature_pattern = '^$'


let s:parser = s:A.new({
      \ 'name': 'Gita[!]',
      \ 'description': [
      \   'An awesome git handling plugin for Vim',
      \ ],
      \})
call s:parser.add_argument(
      \ 'action', [
      \   'An action of the Gita or git command.',
      \   'If a non Gita command is specified or a command is called with a bang (!)',
      \   'it call a raw git command instead of a Gita command.',
      \ ], {
      \   'terminal': 1,
      \   'complete': function('gita#features#_complete_action'),
      \ })
function! s:is_interactive_required(args) abort " {{{
  let required_cases = [
        \ ['^%(add|reset)$', '^%(-i|--interactive|-p|--patch)$'],
        \ ['^rebase$',       '^%(-i|--interactive)$'],
        \]
  if len(a:args) > 0
    for [a, o] in required_cases
      if a:args[0] =~# '\v' . a && s:L.any(a:args, printf('v:val =~# "%s"', '\v' . o))
        return 1
      endif
    endfor
  endif
  return 0
endfunction " }}}

function! gita#features#_clear() abort " {{{
  let s:feature_registry = {}
  let s:feature_pattern = '^$'
endfunction " }}}
function! gita#features#is_registered(name) abort " {{{
  return a:name =~# s:feature_pattern
endfunction " }}}
function! gita#features#register(name, command, complete, ...) abort " {{{
  if gita#features#is_registered(a:name) && !g:gita#debug
    throw printf(
          \ 'vim-gita: a feature "%s" has already been registered.',
          \ a:name,
          \)
  endif
  let s:feature_registry[a:name] = {
        \ 'command': a:command,
        \ 'complete': a:complete,
        \ 'instance': get(a:000, 0, {}),
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
    let name = get(opts, 'action')
    if empty(name)
      echo s:parser.help()
    elseif opts.__bang__ || !gita#features#is_registered(name)
      " execute git command
      let gita = gita#get()
      let args = map(opts.__args__, 'gita#utils#path#expand(v:val)')
      call gita.operations.exec_raw(args, {
            \ 'interactive': s:is_interactive_required(args),
            \})
    else
      " execute Gita command
      let feature = s:feature_registry[name]
      let args = [a:bang, a:range, join(opts.__unknown__)]
      if empty(get(feature, 'instance', {}))
        call call(feature.command, args)
      else
        call call(feature.command, args, feature.instance)
      endif
    endif
  endif
endfunction " }}}
function! gita#features#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\C\v^Gita!?\s', '', '')
  let cmdline = substitute(cmdline, '\v[^ ]*$', '', '')
  let opts = s:parser.parse(bang, [0, 0], cmdline)
  let name = get(opts, 'action', 'help')

  if opts.__bang__ || !gita#features#is_registered(name)
    let candidates = s:parser.complete(a:arglead, a:cmdline, a:cursorpos, opts)
  else
    " execute Gita command
    let feature = s:feature_registry[name]
    "let cmdline = join(extend([name], opts.__unknown__))
    let args = [a:arglead, cmdline, a:cursorpos]
    if empty(get(feature, 'instance', {}))
      let candidates = call(feature.complete, args)
    else
      let candidates = call(feature.complete, args, feature.instance)
    endif
  endif
  return candidates
endfunction " }}}
function! gita#features#_complete_action(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita_features = keys(s:feature_registry)
  let git_features = [
        \ 'push', 'pull', 'submodule', 'remote',
        \]
  return filter(
        \ deepcopy(extend(gita_features, git_features)),
        \ 'v:val =~# "^" . a:arglead',
        \)
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
call gita#features#register('blame',
      \ function('gita#features#blame#command'),
      \ function('gita#features#blame#complete'),
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

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
