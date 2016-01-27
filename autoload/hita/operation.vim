let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Path = s:V.import('System.Filepath')
let s:GitCore = s:V.import('VCS.Git.Core')
let s:splitargs = s:V.import('ArgumentParser').splitargs
let s:is_windows = s:Prelude.is_windows()

let s:schemes = {}
let s:schemes.apply = {
      \ 'include': '--%k %v',
      \ 'exclude': '--%k %v',
      \ 'p': '-%k %v',
      \ 'build-fake-ancestor': '--%k %v',
      \ 'C': '-%k %v',
      \ 'whitespace': '--%k %v',
      \ 'directory': '--%k %v',
      \}
let s:schemes.blame = {
      \ 'commit': '%v',
      \}
let s:schemes.branch = {
      \ 'merged': '--%k %v',
      \ 'no-merged': '--%k %v',
      \ '-u': '-%k %v',
      \ '--set-upstream-to': '--%k %v',
      \ '--contains': '--%k %v',
      \}
let s:schemes.diff = {
      \ 'commit': '%v',
      \}
let s:schemes.log = {}
let s:schemes['ls-files'] = {
      \ 'x': '-%k %v',
      \ 'X': '-%k %v',
      \ 'exclude': '--%k %v',
      \ 'exclude-from': '--%k %v',
      \ 'exclude-per-directory': '--%k %v',
      \ 'with-tree': '--%k %v',
      \}
let s:schemes['merge-base'] = {
      \ 'commit': '%v',
      \ 'commit1': '%v',
      \ 'commit2': '%v',
      \}
let s:schemes.show = {
      \ 'object': '%v',
      \}
let s:schemes.tag = {
      \ 'n': '-%k%v',
      \ 'm': '-%k %v',
      \ 'message': '--%k %v',
      \ 'F': '-%k %v',
      \ 'file': '--%k %v',
      \ 'cleanup': '--%k %v',
      \ 'u': '-%k %v',
      \ 'local-user': '--%k %v',
      \ 'sort': '--%k %v',
      \ 'contains': '--%k %v',
      \ 'points-at': '--%k %v',
      \}

function! s:remove_ansi_sequences(val) abort
  return substitute(a:val, '\v\e\[%(%(\d;)?\d{1,2})?[mK]', '', 'g')
endfunction
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
      call extend(args, s:splitargs(
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
function! s:execute(hita, args, config) abort
  let args = filter(copy(a:args), '!empty(v:val)')
  if a:hita.enabled
    let result = a:hita.git.exec(args, a:config)
  else
    let result = s:GitCore.exec(args, a:config)
  endif
  let result.stdout = s:remove_ansi_sequences(result.stdout)
  return result
endfunction

function! hita#operation#exec(hita, name, ...) abort
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let l:Scheme = get(s:schemes, a:name, {})
  if s:Prelude.is_funcref(l:Scheme)
    let args = l:Scheme(a:name, options)
  else
    let args = s:translate_options(options, l:Scheme)
  endif
  let args = extend([a:name], args)
  return s:execute(a:hita, args, config)
endfunction
