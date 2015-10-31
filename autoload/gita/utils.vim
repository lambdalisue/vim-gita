let s:save_cpo = &cpo
set cpo&vim

function! s:smart_string(value) abort " {{{
  let vtype = type(a:value)
  if vtype == type('')
    return a:value
  elseif vtype == type(0)
    return a:value ? string(a:value) : ''
  elseif vtype == type([]) || vtype == type({})
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
    let result = s:smart_string(get(a:data, value, ''))
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', escape(result, '\')) : ''
    let str = substitute(str, '\C' . pattern, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction " }}}
function! gita#utils#eget(obj, name, ...) abort " {{{
  let default = get(a:000, 0, '')
  let result = get(a:obj, a:name, default)
  return empty(result) ? default : result
endfunction " }}}
function! gita#utils#sget(objs, name, ...) abort " {{{
  for obj in a:objs
    if has_key(obj, a:name)
      return get(obj, a:name)
    endif
  endfor
  return get(a:000, 0, '')
endfunction " }}}
function! gita#utils#clip(content) abort " {{{
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
