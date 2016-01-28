function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Path = a:V.import('System.Filepath')
  let s:StringExt = a:V.import('Data.String.Extra')
  let s:Git = a:V.import('Git')
  let s:is_windows = s:Prelude.is_windows()
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'System.Filepath',
        \ 'Data.String.Extra',
        \ 'Git',
        \ 'ArgumentParser',
        \]
endfunction
function! s:_vital_created(module) abort
  call extend(a:module, {
        \ 'schemes': s:schemes,
        \})
endfunction

function! s:_throw(msg) abort
  throw 'vital: ' . a:msg
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

function! s:translate_option(key, val, pattern) abort
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
  let data = {
        \ 'key': a:key,
        \ 'val': val,
        \ 'escaped_key': substitute(a:key, '_', '-', 'g'),
        \ 'escaped_val': len(val)
        \   ? s:StringExt.shellescape_when_required(val)
        \   : '',
        \}
  return s:StringExt.format(format, format_map, data)
endfunction
function! s:translate_options(options, scheme) abort
  let args = []
  for key  in sort(keys(a:options))
    if key !~# '^__.\+__$' && key !=# '--'
      let pattern = get(a:scheme, key, '')
      call extend(args, s:splitargs(
            \ s:translate_option(key, a:options[key], pattern)
            \))
    endif
  endfor
  if has_key(a:options, '--')
    call add(args, '--')
    for str in a:options['--']
      call add(args, fnameescape(expand(str)))
    endfor
  endif
  return args
endfunction

function! s:execute(git, name, ...) abort
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let l:Scheme = get(s:schemes, a:name, {})
  if s:Prelude.is_funcref(l:Scheme)
    let args = l:Scheme(a:name, options)
  else
    let args = s:translate_options(options, l:Scheme)
  endif
  let args = filter(extend([a:name], args), '!empty(v:val)')
  return s:Git.system(a:git, args, config)
endfunction

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
      \ 'L': '--%k %v',
      \ 'S': '--%k %v',
      \ 'contents': '--%k %V',
      \ 'date': '--%k %V',
      \ 'commit': '%v',
      \}
let s:schemes.checkout = {
      \ 'b': '-%k %v',
      \ 'B': '-%k %v',
      \ 'commit': '%v',
      \}
let s:schemes.branch = {
      \ 'merged': '--%k %v',
      \ 'no-merged': '--%k %v',
      \ 'u': '-%k %v',
      \ 'set-upstream-to': '--%k %v',
      \ 'contains': '--%k %v',
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
      \ 'fork_point': '--%K %v',
      \ 'commit': '%v',
      \ 'commit1': '%v',
      \ 'commit2': '%v',
      \}
let s:schemes.show = {
      \ 'object': '%v',
      \}
let s:schemes['rev-parse'] = {
      \ 'default': '--%K %V',
      \ 'prefix': '--%K %V',
      \ 'resolve_git_dir': '--%K %V',
      \ 'args': '%v',
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
let s:schemes.reset = {
      \ 'commit': '%v',
      \}
let s:schemes.commit = {
      \ 'C': '-%k %v',
      \ 'c': '-%k %v',
      \ 'F': '-%k %v',
      \ 'm': '-%k %v',
      \ 't': '-%k %v',
      \}
function! s:schemes.clone(name, options) abort
  let scheme = {
        \ 'reference': '--%K %V',
        \ 'o': '-%K %V',
        \ 'origin': '--%K %V',
        \ 'b': '-%K %V',
        \ 'branch': '--%K %V',
        \ 'u': '-%K %V',
        \ 'upload-pack': '--%K %V',
        \ 'c': '-%K %V',
        \ 'configig': '--%K %V',
        \ 'depth': '--%K %V',
        \}
  let args = s:translate_options(a:options, scheme)
  return extend(args, [
        \ '--',
        \ get(a:options, 'repository', ''),
        \ get(a:options, 'directory', ''),
        \])
endfunction

