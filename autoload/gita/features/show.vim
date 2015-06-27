let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')

" Note:
"   while 'git show' has too many options, I decied to NOT support in Gita.
"   command feature. But the function is used in several other features.

function! gita#features#show#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'object',
        \])
  return gita.operations.show(options, config)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
