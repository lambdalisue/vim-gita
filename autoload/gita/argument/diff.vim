let s:save_cpo = &cpo
set cpo&vim

let s:ArgumentParser = gita#util#import('ArgumentParser')

function! gita#argument#diff#get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \   'name': 'Show changes between commits, commit and working tree, etc',
          \   'validate_unknown': 0,
          \ })
  endif
  return s:parser
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
