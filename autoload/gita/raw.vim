let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')


function! s:parse_options(opts, format) abort " {{{
  let arg = []
  for [key, value] in items(a:opts)
    if key =~# '^--$'
      call add(args, value)
    if key =~# '^--?'
      let opts[key] = value
    else
      let args
    endif
  endfor
endfunction " }}}
function! s:validate_options(opts, available_option_keys) abort " {{{
  let invalid_options = s:D.omit(a:opts, a:available_option_keys)
  if !empty(invalid_options)
    call gita#utils#error(
          \ 'vim-gita: The following unknown options are specified:'
          \)
    for key in keys(invalid_options)
      call gita#utils#info(printf('* %s', key))
    endfor
    return 1
  endif
  return 0
endfunction " }}}

function! gita#raw#status(opts) abort " {{{
  let available_option_keys = [
        \ '-s', '--short',
        \ '-b', '--branch',
        \ '--porecelain',
        \ '--long',
        \ '-u', '--untracked-files',
        \ '--ignore-submodules',
        \ '--ignored',
        \ '-z',
        \ '--column', '--no-column',
        \]
  if s:validate_options(a:opts, available_option_keys)
    return ''
  endif

  let args
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
