let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vim_gita')
function! gita#utils#import(name) abort " {{{
  let cache_name = printf(
        \ '_vital_module_%s',
        \ substitute(a:name, '\.', '_', 'g'),
        \)
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:V.import(a:name)
  endif
  return s:[cache_name]
endfunction " }}}

let s:P = gita#utils#import('Prelude')
let s:T = gita#utils#import('DateTime')
let s:S = gita#utils#import('VCS.Git.StatusParser')


" echo
function! gita#utils#echo(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#debug(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echo('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#utils#info(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echo('None', join(args))
endfunction " }}}
function! gita#utils#title(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echo('Title', join(args))
endfunction " }}}
function! gita#utils#warn(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echo('WarningMsg', join(args))
endfunction " }}}
function! gita#utils#error(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echo('Error', join(args))
endfunction " }}}

" echomsg
function! gita#utils#echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#debugmsg(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echomsg('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gita#utils#titlemsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echomsg('Title', join(args))
endfunction " }}}
function! gita#utils#infomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echomsg('None', join(args))
endfunction " }}}
function! gita#utils#warnmsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echomsg('WarningMsg', join(args))
endfunction " }}}
function! gita#utils#errormsg(...) abort " {{{
  let args = map(deepcopy(a:000), 'gita#utils#ensure_string(v:val)')
  call gita#utils#echomsg('Error', join(args))
endfunction " }}}

" input
function! gita#utils#input(hl, msg, ...) abort " {{{
  execute 'echohl' a:hl
  try
    return input(a:msg, get(a:000, 0, ''))
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#utils#ask(message, ...) abort " {{{
  let result = gita#utils#input('Question', a:message, get(a:000, 0, ''))
  redraw
  return result
endfunction " }}}
function! gita#utils#asktf(message, ...) abort " {{{
  let result = gita#utils#ask(
        \ printf('%s (y[es]/n[o]): ', a:message),
        \ get(a:000, 0, ''))
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result == ''
      call gita#utils#warn('Canceled.')
      break
    endif
    call gita#utils#error('Invalid input.')
    let result = gita#utils#ask(printf('%s (y[es]/n[o]): ', a:message))
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}

" string
function! gita#utils#smart_string(value) abort " {{{
  let P = gita#utils#import('Prelude')
  if P.is_string(a:value)
    return a:value
  elseif P.is_numeric(a:value)
    return a:value ? string(a:value) : ''
  elseif P.is_list(a:value) || P.is_dict(a:value)
    return !empty(a:value) ? string(a:value) : ''
  else
    return string(a:value)
  endif
endfunction " }}}
function! gita#utils#format_string(format, format_map, data) abort " {{{
  " format rule:
  "   %{<left>|<right>}<key>
  "     '<left><value><right>' if <value> != ''
  "     ''                     if <value> == ''
  "   %{<left>}<key>
  "     '<left><value>'        if <value> != ''
  "     ''                     if <value> == ''
  "   %{|<right>}<key>
  "     '<value><right>'       if <value> != ''
  "     ''                     if <value> == ''
  if empty(a:data)
    return ''
  endif
  let pattern_base = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, value] in items(a:format_map)
    let result = gita#utils#smart_string(get(a:data, value, ''))
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pattern, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction " }}}

" ensure
function! gita#utils#ensure_string(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_string(a:x) ? a:x : [a:x]
endfunction " }}}
function! gita#utils#ensure_list(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_list(a:x) ? a:x : [a:x]
endfunction " }}}

" misc
function! gita#utils#get_status(path) abort " {{{
  let gita = gita#get()
  let options = {
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \ '--': [a:path],
        \}
  let result = gita.operations.status(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return {}
  endif
  let statuses = s:S.parse(result.stdout)
  return get(statuses.all, 0, {})
endfunction " }}}
function! gita#utils#doautocmd(name) abort " {{{
  let name = printf('vim-gita-%s', a:name)
  if 703 < v:version || (v:version == 703 && has('patch438'))
    silent execute 'doautocmd <nomodeline> User ' . name
  else
    silent execute 'doautocmd User ' . name
  endif
endfunction " }}}
function! gita#utils#expand(expr) abort " {{{
  " prefer 'b:_gita_original_filename'
  return getbufvar(a:expr, '_gita_original_filename', expand(a:expr))
endfunction " }}}
function! gita#utils#format_timestamp(timestamp, ...) abort " {{{
  let timezone = get(a:000, 0, '')
  let prefix1 = get(a:000, 1, '')
  let prefix2 = get(a:000, 2, '')
  let time = s:T.from_unix_time(a:timestamp, timezone)
  let delta = time.delta(s:T.now())
  if delta.years() < 1
    return prefix1 . delta.about()
  else
    return prefix2 . time.format('%d %b, %Y')
  endif
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
