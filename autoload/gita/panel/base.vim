let s:save_cpo = &cpo
set cpo&vim


function! gita#panel#base#extend_options(options) abort " {{{
  return extend(
        \ deepcopy(get(w:, '_gita_options', {})),
        \ deepcopy(a:options),
        \)
endfunction " }}}
function! gita#panel#base#open(name, ...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available on the current buffer',
          \)
    return -1
  endif

  let options = gita#panel#base#extend_options(
        \ get(a:000, 0, {}),
        \)
endfunction " }}}
let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
