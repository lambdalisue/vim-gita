let s:save_cpoptions = &cpoptions
set cpoptions&vim

" getcurpos
" https://github.com/vim-jp/vim/commit/0ea3beb7e39b21e2c6e6fd4f9a3121747bebe09f
if (v:version == 704 && has('patch313')) || v:version > 704
  function! gita#compat#getcurpos() abort " {{{
    return getcurpos()
  endfunction
else
  function! gita#compat#getcurpos() abort " {{{
    return getpos('.')
  endfunction
endif

" doautocmd User with <nomodeline>
" https://github.com/vim-jp/vim/commit/8399b184df06f80ca030b505920dd3e97be72f20
if (v:version == 703 && has('patch438')) || v:version >= 704
  function! gita#compat#doautocmd(name) abort " {{{
    silent execute printf('doautocmd <nomodeline> User %s', a:name)
  endfunction " }}}
else
  function! gita#compat#doautocmd(name) abort " {{{
    silent execute printf('doautocmd User %s', a:name)
  endfunction " }}}
endif

" getbufvar, getwinvar with default value
" https://github.com/vim-jp/vim/commit/51d92c00e8c731c3b8f79b1e5f3e6b47cb1d1192
if (v:version == 703 && has('patch831')) || v:version >= 704
  function! gita#compat#getbufvar(...) abort " {{{
    return call('getbufvar', a:000)
  endfunction " }}}
  function! gita#compat#getwinvar(...) abort " {{{
    return call('getwinvar', a:000)
  endfunction " }}}
else
  function! gita#compat#getbufvar(expr, varname, ...) abort " {{{
    let v = getbufvar(a:expr, a:varname)
    return empty(v) ? get(a:000, 0, '') : v
  endfunction " }}}
  function! gita#compat#getwinvar(expr, varname, ...) abort " {{{
    let v = getwinvar(a:expr, a:varname)
    return empty(v) ? get(a:000, 0, '') : v
  endfunction " }}}
endif

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
