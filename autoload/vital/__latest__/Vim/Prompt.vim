let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort " {{{
  let s:Prelude = a:V.import('Prelude')
  let s:Dict = a:V.import('Data.Dict')
  let s:config = {
        \ 'debug': 0,
        \ 'batch': 0,
        \}
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'Data.Dict',
        \]
endfunction " }}}
function! s:_ensure_string(x) abort
  return type(a:x) == type('') ? a:x : string(a:x)
endfunction

function! s:get_config() abort
  return deepcopy(s:config)
endfunction
function! s:set_config(config) abort
  let s:config = extend(s:config, s:Dict.pick(a:config, [
        \ 'debug', 'batch',
        \]))
endfunction

function! s:is_batch() abort
  if s:Prelude.is_funcref(s:config.batch)
    return s:config.batch()
  else
    return s:config.batch
  endif
endfunction
function! s:is_debug() abort
  if s:Prelude.is_funcref(s:config.debug)
    return s:config.debug()
  else
    return s:config.debug
  endif
endfunction

function! s:echo(hl, msg) abort
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction
function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction
function! s:input(hl, msg, ...) abort
  if s:is_batch()
    return ''
  endif
  execute 'echohl' a:hl
  call inputsave()
  try
    if empty(get(a:000, 1, ''))
      return input(a:msg, get(a:000, 0, ''))
    else
      return input(a:msg, get(a:000, 0, ''), get(a:000, 1, ''))
    endif
  finally
    echohl None
    call inputrestore()
  endtry
endfunction
function! s:inputlist(hl, textlist) abort
  if s:is_batch()
    return 0
  endif
  execute 'echohl' a:hl
  call inputsave()
  try
    return inputlist(a:textlist)
  finally
    echohl None
    call inputrestore()
  endtry
endfunction

" @vimlint(EVL102, 1, l:i)
function! s:clear() abort
  for i in range(201)
    echomsg ''
  endfor
endfunction
" @vimlint(EVL102, 0, l:i)

function! s:debug(...) abort
  if !s:is_debug()
    return
  endif
  call s:echomsg(
        \ 'Comment',
        \ join(map(copy(a:000), 's:_ensure_string(v:val)'), "\n")
        \)
endfunction
function! s:info(...) abort
  call s:echomsg(
        \ 'Title',
        \ join(map(copy(a:000), 's:_ensure_string(v:val)'), "\n")
        \)
endfunction
function! s:warn(...) abort
  call s:echomsg(
        \ 'WarningMsg',
        \ join(map(copy(a:000), 's:_ensure_string(v:val)'), "\n")
        \)
endfunction
function! s:error(...) abort
  call s:echomsg(
        \ 'Error',
        \ join(map(copy(a:000), 's:_ensure_string(v:val)'), "\n")
        \)
endfunction

function! s:ask(msg, ...) abort
  if s:is_batch()
    return ''
  endif
  let result = s:input(
        \ 'Question',
        \ s:_ensure_string(a:msg),
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction
function! s:select(msg, candidates, ...) abort
  let canceled = get(a:000, 0, '')
  if s:is_batch()
    return canceled
  endif
  let candidates = map(
        \ copy(a:candidates),
        \ 'printf(''%d. %s'', v:key+1, s:_ensure_string(v:val))'
        \)
  let result = s:inputlist('Question', extend([a:msg], candidates))
  redraw
  return result == 0 ? canceled : a:candidates[result-1]
endfunction
function! s:confirm(msg, ...) abort
  if s:is_batch()
    return 0
  endif
  let result = s:input(
        \ 'Question',
        \ printf('%s (y[es]/n[o]): ', a:msg),
        \ get(a:000, 0, ''),
        \ 'customlist,s:_confirm_complete',
        \)
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result ==# ''
      call s:echo('WarningMsg', 'Canceled.')
      break
    endif
    call s:echo('WarningMsg', 'Invalid input.')
    let result = s:input(
          \ 'Question',
          \ printf('%s (y[es]/n[o]): ', a:msg),
          \ get(a:000, 0, ''),
          \ 'customlist,s:_confirm_complete',
          \)
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction
function! s:_confirm_complete(arglead, cmdline, cursorpos) abort
  return filter(['yes', 'no'], 'v:val =~# "^" . a:arglead')
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
