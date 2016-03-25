let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')

function! s:smart_string(value) abort
  if s:Prelude.is_string(a:value)
    return a:value
  elseif s:Prelude.is_number(a:value)
    return a:value ? string(a:value) : ''
  elseif s:Prelude.is_list(a:value) || s:Prelude.is_dict(a:value)
    return !empty(a:value) ? string(a:value) : ''
  else
    return string(a:value)
  endif
endfunction

function! gita#util#formatter#format(format, format_map, data) abort
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
  let pattern_base = '\C%\%({\([^|}]*\)\%(|\([^}]*\)\)\?}\)\?'
  let str = copy(a:format)
  for [key, Value] in items(a:format_map)
    let pattern = pattern_base . key
    if str =~# pattern
      if s:Prelude.is_funcref(Value)
        let result = s:smart_string(call(Value, [a:data], a:format_map))
      else
        let result = s:smart_string(get(a:data, Value, ''))
      endif
      let repl = strlen(result) ? '\1' . escape(result, '\') . '\2' : ''
      let str = substitute(str, pattern, repl, 'g')
    endif
    unlet! Value
  endfor
  return substitute(str, '^\s\+\|\s\+$', '', 'g')
endfunction
