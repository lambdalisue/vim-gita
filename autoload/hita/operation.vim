let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Path = s:V.import('System.Filepath')
let s:GitCore = s:V.import('VCS.Git.Core')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:is_windows = s:Prelude.is_windows()

let s:schemes = {}
let s:schemes.show = {
      \ 'object': '%v',
      \}
let s:schemes.merge_base = {
      \ 'fork_point': '--%K %v',
      \ 'commit': '%v',
      \ 'commit1': '%v',
      \ 'commit2': '%v',
      \}

function! s:prefer_shellescape(val) abort " {{{
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
endfunction " }}}
function! s:translate_option(key, val, pattern) abort " {{{
  if s:Prelude.is_number(a:val)
    if a:val == 0
      return ''
    endif
    let val = ''
  else
    let val = a:val
  endif
  if len(a:key) == 1
    let format = empty(a:pattern) ? '-%k%v' : a:pattern
  else
    let format = empty(a:pattern) ? '--%K%{=}V' : a:pattern
  endif
  let format_map = {
        \ 'k': 'key',
        \ 'v': 'val',
        \ 'K': 'escaped_key',
        \ 'V': 'escaped_val',
        \ 'u': 'unixpath_val',
        \ 'U': 'escaped_unixpath_val',
        \ 'r': 'realpath_val',
        \ 'R': 'escaped_realpath_val',
        \}
  let abspath = s:Path.abspath(val)
  let data = {
        \ 'key': a:key,
        \ 'val': val,
        \ 'escaped_key': substitute(a:key, '_', '-', 'g'),
        \ 'escaped_val': len(val) ? s:prefer_shellescape(val) : '',
        \}
  return hita#util#string#format(format, format_map, data)
endfunction " }}}
function! s:translate_options(options, scheme) abort " {{{
  let args = []
  for [key, val]  in items(a:options)
    if key !~# '^__.\+__$' && key !=# '--'
      let pattern = get(a:scheme, key, '')
      call extend(args, s:ArgumentParser.splitargs(
            \ s:translate_option(key, val, pattern)
            \))
    endif
    unlet! val
  endfor
  if has_key(a:options, '--')
    call add(args, '--')
    for str in a:options['--']
      call add(args, fnameescape(hita#expand(str)))
    endfor
  endif
  return args
endfunction
function! s:execute(hita, args) abort
  let args = filter(copy(a:args), '!empty(v:val)')
  if a:hita.enabled
    let result = a:hita.git.exec(args)
  else
    let result = s:GitCore.exec(args)
  endif
  let result.stdout = hita#util#string#remove_ansi_sequences(result.stdout)
  return result
endfunction

function! hita#operation#exec(hita, name, ...) abort
  let options = get(a:000, 0, {})
  let l:Scheme = get(s:schemes, a:name, {})
  if s:Prelude.is_funcref(l:Scheme)
    let args = l:Scheme(a:name, options)
  else
    let args = s:translate_options(options, l:Scheme)
  endif
  let args = extend([a:name], args)
  return s:execute(a:hita, args)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
