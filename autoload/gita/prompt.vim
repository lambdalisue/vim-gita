let s:save_cpo = &cpoptions
set cpoptions&vim


function! s:ensure_string(x) abort " {{{
  return type(a:x) == type('')
        \ ? a:x
        \ : string(a:x)
endfunction " }}}
function! s:echo(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! s:echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! s:input(hl, msg, ...) abort " {{{
  if get(g:, 'gita#test')
    return ''
  endif
  execute 'echohl' a:hl
  try
    if empty(get(a:000, 1, ''))
      return input(a:msg, get(a:000, 0, ''))
    else
      return input(a:msg, get(a:000, 0, ''), get(a:000, 1, ''))
    endif
  finally
    echohl None
  endtry
endfunction " }}}

function! gita#prompt#echo(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('None', join(args))
endfunction " }}}
function! gita#prompt#debug(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#prompt#info(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Title', join(args))
endfunction " }}}
function! gita#prompt#warn(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('WarningMsg', join(args))
endfunction " }}}
function! gita#prompt#error(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Error', join(args))
endfunction " }}}

function! gita#prompt#echomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('None', join(args))
endfunction " }}}
function! gita#prompt#debugmsg(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#prompt#infomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Title', join(args))
endfunction " }}}
function! gita#prompt#warnmsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('WarningMsg', join(args))
endfunction " }}}
function! gita#prompt#errormsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Error', join(args))
endfunction " }}}

function! gita#prompt#input(msg, ...) abort " {{{
  let result = s:input(
        \ 'None', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction " }}}
function! gita#prompt#ask(msg, ...) abort " {{{
  let result = s:input(
        \ 'Question', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction " }}}
function! gita#prompt#asktf(msg, ...) abort " {{{
  let result = gita#prompt#ask(
        \ printf('%s (y[es]/n[o]): ', a:msg),
        \ get(a:000, 0, ''),
        \ 'customlist,gita#prompt#_asktf_complete_yes_or_no',
        \)
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result ==# ''
      call gita#prompt#warn('Canceled.')
      break
    endif
    call gita#prompt#error('Invalid input.')
    let result = gita#prompt#ask(
          \ printf('%s (y[es]/n[o]): ', a:msg),
          \ get(a:000, 0, ''),
          \ 'customlist,gita#prompt#_asktf_complete_yes_or_no',
          \)
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}
function! gita#prompt#_asktf_complete_yes_or_no(arglead, cmdline, cursorpos) abort " {{{
  return filter(['yes', 'no'], 'v:val =~# ''^'' . a:arglead')
endfunction " }}}


let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
