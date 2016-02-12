function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  " As of 7.4.122, the system()'s 1st argument is converted internally by Vim.
  let s:require_encode_prior_to_system = v:version < 704 || (v:version == 704 && !has('patch122'))
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \]
endfunction

function! s:_throw(msg) abort
  throw printf('vital: Vim.Process: %s', a:msg)
endfunction

function! s:has_vimproc() abort
  if !exists('s:exists_vimproc')
    try
      call vimproc#version()
      let s:exists_vimproc = 1
    catch
      let s:exists_vimproc = 0
    endtry
  endif
  return s:exists_vimproc
endfunction

function! s:iconv(expr, from, to) abort
  if a:from ==# '' || a:to ==# '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return empty(result) ? a:expr : result
endfunction

function! s:get_last_status(...) abort
  let use_vimproc = get(a:000, 0, s:has_vimproc())
  if use_vimproc && !s:has_vimproc()
    call s:_throw('{use_vimproc} is specified but vimproc is not available')
  endif
  return use_vimproc
        \ ? vimproc#get_last_status()
        \ : v:shell_error
endfunction

function! s:repair_posix_text(text, ...) abort
  " NOTE:
  " A definition of a TEXT file is "A file that contains characters organized
  " into one or more lines."
  " A definition of a LINE is "A sequence of zero ore more non- <newline>s
  " plus a terminating <newline>"
  " That's why {stdin} always end with <newline> ideally. However, there are
  " some program which does not follow the POSIX rule and a Vim's way to join
  " List into TEXT; join({text}, "\n"); does not add <newline> to the end of
  " the last line.
  " That's why add a trailing <newline> if it does not exist.
  " REF:
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
  " :help split()
  " NOTE:
  " it does nothing if the text is a correct POSIX text
  let newline = get(a:000, 0, "\n")
  return a:text =~# '\r\?\n$' ? a:text : a:text . newline
endfunction

function! s:join_posix_lines(lines, ...) abort
  " NOTE:
  " A definition of a TEXT file is "A file that contains characters organized
  " into one or more lines."
  " A definition of a LINE is "A sequence of zero ore more non- <newline>s
  " plus a terminating <newline>"
  " REF:
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
  let newline = get(a:000, 0, "\n")
  return join(a:lines, newline) . newline
endfunction

function! s:split_posix_text(text, ...) abort
  " NOTE:
  " A definition of a TEXT file is "A file that contains characters organized
  " into one or more lines."
  " A definition of a LINE is "A sequence of zero ore more non- <newline>s
  " plus a terminating <newline>"
  " TEXT into List; split({text}, '\r\?\n', 1); add an extra empty line at the
  " end of List because the end of TEXT ends with <newline> and keepempty=1 is
  " specified. (btw. keepempty=0 cannot be used because it will remove
  " emptylines in head and tail).
  " That's why remove a trailing <newline> before proceeding to 'split'
  " REF:
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
  let newline = get(a:000, 0, '\r\?\n')
  let text = substitute(a:text, newline . '$', '', '')
  return split(text, newline, 1)
endfunction

function! s:shellescape(string, ...) abort
  let special = get(a:000, 0, 0)
  if a:string =~# '\s' && a:string !~# '^".*"$' && a:string !~# "^'.*'$"
    " the string contains spaces but not enclosed yet
    return shellescape(a:string, special)
  endif
  " the string does not contains spaces or already enclosed
  let string = a:string
  if special
    let string = substitute(string, '<cword>', '\\<cword>', 'g')
    let string = escape(string, '!%#')
  endif
  return string
endfunction

function! s:shellescape_vimproc(string, ...) abort
  " NOTE:
  " Somehow vimproc#system() parse 'cmdline' in a vimproc's mannor and some
  " special characters requires to be escaped additionally to builtin system()
  " For example, the following @{upstream}.. will be converted into @u..
  " without escape which works fine in builtin system()
  "
  "   git log --oneline @{upstream}..
  "
  " Probably { is used in ${VARIABLE} context so escape { without leading $
  " is required I guess
  " https://github.com/Shougo/vimproc.vim/issues/239
  let string = call('s:shellescape', [a:string] + a:000)
  let string = substitute(string, '[^$]\zs{', '\\{', 'g')
  " NOTE:
  " Backslash in Windows should be escaped
  if s:Prelude.is_windows()
    let string = escape(string, '\')
  endif
  return string
endfunction

function! s:_system(args, options) abort
  if s:Prelude.is_list(a:args)
    let cmdline = join(map(copy(a:args), a:options.use_vimproc
          \ ? 's:shellescape_vimproc(v:val)'
          \ : 's:shellescape(v:val)'
          \), ' ')
  else
    let cmdline = a:args
  endif
  if !a:options.use_vimproc
        \ && (v:version < 704 || (v:version == 704 && !has('patch122')))
    " XXX : Need information about what is 'char'
    " {cmdline} of system() before Vim 7.4.122 is not converted so convert
    " it manually from &encoding to 'char'
    let cmdline = s:iconv(cmdline, &encoding, 'char')
  endif
  if a:options.background
        \ && (a:options.use_vimproc || !s:Prelude.is_windows())
    let cmdline = cmdline . '&'
  endif
  if s:Prelude.is_string(a:options.input) && !empty(a:options.encode_input)
    let encoding = s:Prelude.is_string(a:options.encode_input)
          \ ? a:options.encode_input
          \ : &encoding
    let input = s:iconv(a:options.input, encoding, 'char')
  else
    let input = a:options.input
  endif
  if a:options.repair_input
    let input = s:repair_posix_text(input)
  endif
  let args = [cmdline] + (s:Prelude.is_string(a:options.input) ? [input] : [])
  let fname = a:options.use_vimproc ? 'vimproc#system' : 'system'
  if &verbose > 0
    echomsg printf('vital: Vim.Process: %s() : %s', fname, join(args, ' '))
  endif
  let output = call(fname, args)
  if s:Prelude.is_windows() && !a:options.use_vimproc
    " A builtin system() add a trailing space in Windows.
    " It is probably an issue of redirection in Windows so remove it.
    let output = substitute(output, '\s\n$', '\n', '')
  endif
  if !empty(a:options.encode_output)
    let encoding = s:Prelude.is_string(a:options.encode_output)
          \ ? a:options.encode_output
          \ : &encoding
    let output = s:iconv(output, 'char', encoding)
  endif
  return output
endfunction
function! s:system(args, ...) abort
  if a:0 == 3
    " system({args}, {input}, {timeout}, {options})
    let options = a:3
    let timeout = a:2
    let input = a:1
  elseif a:0 == 2
    if s:Prelude.is_dict(a:2)
      " system({args}, {input}, {options})
      let options = a:2
      let timeout = 0
      let input = a:1
    else
      " system({args}, {input}, {timeout})
      let options = {}
      let timeout = a:2
      let input = a:1
    endif
  elseif a:0 == 1
    if s:Prelude.is_dict(a:1)
      " system({args}, {options})
      let options = a:1
      let timeout = 0
      let input = 0
    else
      " system({args}, {input})
      let options = {}
      let timeout = 0
      let input = a:1
    endif
  elseif a:0 == 0
    " system({args})
    let options = {}
    let timeout = 0
    let input = 0
  else
    call s:_throw(printf(
          \ 'system() expects 1-4 arguments but %d arguments were specified',
          \ a:0 + 1
          \))
    " the following is not called but for lint
    let options = {}
    let timeout = 0
    let input = 0
  endif
  " Validate variable types
  if !s:Prelude.is_dict(options)
    call s:_throw(printf(
          \ '{options} of system() requires to be a dictionary but "%s" was specified',
          \ string(options),
          \))
  endif
  if !s:Prelude.is_number(timeout)
    call s:_throw(printf(
          \ '{timeout} of system() requires to be a number but "%s" was specified',
          \ string(options),
          \))
  endif
  if !(s:Prelude.is_number(input) && input == 0) && !s:Prelude.is_string(input) && !s:Prelude.is_list(input)
    call s:_throw(printf(
          \ '{input} of system() requires to be a string or list but "%s" was specified',
          \ string(options),
          \))
  endif
  if !s:Prelude.is_string(a:args) && !s:Prelude.is_list(a:args)
    call s:_throw(printf(
          \ '{args} of system() requires to be a string or list but "%s" was specified',
          \ string(options),
          \))
  endif
  let _input = (s:Prelude.is_number(input) && input == 0) || s:Prelude.is_string(input)
        \ ? input
        \ : s:join_posix_lines(input)
  let options = extend({
        \ 'use_vimproc': s:has_vimproc(),
        \ 'input': _input,
        \ 'timeout': timeout,
        \ 'background': 0,
        \ 'repair_input': 1,
        \ 'encode_input': 1,
        \ 'encode_output': 1,
        \}, options)
  return s:_system(a:args, options)
endfunction
