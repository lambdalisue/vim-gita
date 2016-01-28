function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:is_windows = s:Prelude.is_windows()
endfunction
function! s:_vital_depends() abort
  return ['Prelude']
endfunction

function! s:smart_string(value) abort
  let vtype = type(a:value)
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

function! s:format(format, format_map, data) abort
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
  for [key, Value] in items(a:format_map)
    if s:Prelude.is_funcref(Value)
      let result = s:smart_string(call(Value, [a:data], a:format_map))
    else
      let result = s:smart_string(get(a:data, Value, ''))
    endif
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', escape(result, '\')) : ''
    let str = substitute(str, '\C' . pattern, repl, 'g')
    unlet! Value
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction

function! s:ensure_eol(text) abort
  return a:text =~# '\r\?\n$' ? a:text : a:text . "\n"
endfunction

function! s:escape_regex(regex) abort
  " escape characters for no-magic
  return escape(a:regex, '^$~.*[]\')
endfunction

function! s:remove_ansi_sequences(text) abort
  return substitute(a:text, '\v\e\[%(%(\d;)?\d{1,2})?[mK]', '', 'g')
endfunction

function! s:remove_trailing_emptyline(text) abort
  return substitute(a:text, '\r\?\n\r\?\n$', "\n", '')
endfunction

function! s:shellescape_when_required(val) abort
  let val = shellescape(a:val)
  if val !~# '\s'
    if !s:is_windows || (exists('&shellslash') && &shellslash)
      let val = substitute(val, "^'", '', 'g')
      let val = substitute(val, "'$", '', 'g')
    else
      " Windows without shellslash enclose value with double quote
      let val = substitute(val, '^"', '', 'g')
      let val = substitute(val, '"$', '', 'g')
    endif
  endif
  return val
endfunction

function! s:capitalize(text) abort
  return substitute(a:text, '\w\+', '\u\0', '')
endfunction
