function! s:_vital_loaded(V) abort dict
  let s:Prelude = a:V.import('Prelude')
endfunction
function! s:_vital_depends() abort
  return ['Prelude']
endfunction

function! s:splitargs(str) abort
  let single_quote = '\v''\zs[^'']+\ze'''
  let double_quote = '\v"\zs[^"]+\ze"'
  let bare_strings = '\v[^ \t''"]+'
  let pattern = printf('\v%%(%s|%s|%s)',
        \ single_quote,
        \ double_quote,
        \ bare_strings,
        \)
  return split(a:str, printf('\v%s*\zs%%(\s+|$)\ze', pattern))
endfunction

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

function! s:unescape(string, chars) abort
  let string = a:string
  for char in split(a:chars, '\zs')
    let escaped_char = escape(char, '^$~.*[]\')
    let string = substitute(
          \ string,
          \ '\\' . escaped_char, 
          \ char,
          \ 'g')
  endfor
  return string
endfunction

function! s:escape_regex(regex) abort
  " unescape characters which is already escaped to prevent double escape
  let regex = s:unescape(a:regex, '^$~.*[]\')
  " escape characters for no-magic
  return escape(regex, '^$~.*[]\')
endfunction

function! s:ensure_eol(text) abort
  return a:text =~# '\r\?\n$' ? a:text : a:text . "\n"
endfunction

function! s:remove_ansi_sequences(text) abort
  return substitute(a:text, '\v\e\[%(%(\d;)?\d{1,2})?[mK]', '', 'g')
endfunction
