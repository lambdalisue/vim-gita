function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Process = a:V.import('Vim.Process')
  let s:Dict = a:V.import('Data.Dict')
  let s:StringExt = a:V.import('Data.StringExt')
  let s:config = {
        \ 'executable': 'git',
        \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
        \}
  let s:is_windows = s:Prelude.is_windows()
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Vim.Process',
        \ 'Data.Dict',
        \ 'Data.StringExt',
        \]
endfunction
function! s:_vital_created(module) abort
  call extend(a:module, {
        \ 'schemes': s:schemes,
        \})
endfunction

function! s:_shellescape(val) abort
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

function! s:get_config() abort
  return copy(s:config)
endfunction
function! s:set_config(config) abort
  let config = s:Dict.pick(a:config, [
        \ 'executable',
        \ 'arguments',
        \])
  call extend(s:config, config)
endfunction

function! s:throw(msg) abort
  if s:Prelude.is_dict(a:msg)
    let msg = printf("%s: %s\n%s",
          \ a:msg.status == 0 ? 'OK' : 'Fail',
          \ join(a:msg.args), a:msg.stdout,
          \)
  else
    let msg = a:msg
  endif
  throw 'vital: Git.Process: ' . msg
endfunction

function! s:translate_option(key, val, pattern) abort
  if s:Prelude.is_list(a:val)
    let args = []
    for val in a:val
      call extend(args, s:translate_option(a:key, val, a:pattern))
    endfor
    return args
  elseif s:Prelude.is_number(a:val)
    if a:val == 0
      return []
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
        \   ? s:_shellescape(val)
        \   : '',
        \}
  return s:StringExt.splitargs(s:StringExt.format(format, format_map, data))
endfunction
function! s:translate_options(options, scheme) abort
  let args = []
  for key  in sort(keys(a:options))
    if key !~# '^__.\+__$' && key !=# '--'
      let pattern = get(a:scheme, key, '')
      call extend(args, s:translate_option(key, a:options[key], pattern))
    endif
  endfor
  return args
endfunction
function! s:translate_extra_options(options) abort
  let args = []
  if has_key(a:options, '--')
    for str in a:options['--']
      call add(args, expand(str))
    endfor
  endif
  return args
endfunction

" s:build_args({name}[, {options}])
function! s:build_args(name, ...) abort
  let options = get(a:000, 0, {})
  let l:Scheme = get(s:schemes, a:name, {})
  if s:Prelude.is_funcref(l:Scheme)
    let args = call(l:Scheme, [a:name, options], s:schemes)
  else
    let args = s:translate_options(options, l:Scheme)
    let extra = s:translate_extra_options(options)
    call extend(args, empty(extra) ? [] : ['--'] + extra)
  endif
  return filter(extend([a:name], args), '!empty(v:val)')
endfunction

" s:execute({git}, {name}[, {options}, {config}])
" s:execute({name}[, {options}, {config}])
function! s:execute(...) abort
  if s:Prelude.is_dict(a:1)
    let worktree = get(a:1, 'worktree', '')
    let args = s:build_args(a:2, get(a:000, 2, {}))
    let args = (empty(worktree) ? [] : ['-C', worktree]) + args
    let config = get(a:000, 4, {})
  else
    let args = s:build_args(a:1, get(a:000, 3, {}))
    let config = get(a:000, 3, {})
  endif
  return s:system(args, config)
endfunction

" s:system({args}[, {config}])
function! s:system(args, ...) abort
  let config = extend({
        \ 'input': 0,
        \ 'timeout': 0,
        \ 'content': 1,
        \ 'repair_input': 1,
        \ 'encode_input': 0,
        \ 'encode_output': 0,
        \}, get(a:000, 0, {}))
  let args = [s:config.executable] + s:config.arguments + a:args
  let stdout = s:Process.system(args, s:Dict.pick(config, [
        \ 'input',
        \ 'timeout',
        \ 'use_vimproc',
        \ 'background',
        \ 'repair_input',
        \ 'encode_input',
        \ 'encode_output',
        \]))
  let result = {
        \ 'args': args,
        \ 'stdout': stdout,
        \ 'status': s:Process.get_last_status(),
        \}
  if config.content
    let result['content'] = s:Process.split_posix_text(stdout)
  endif
  return result
endfunction

let s:schemes = {}
let s:schemes.apply = {
      \ 'p': '-%k%v',
      \ 'C': '-%k%v',
      \}
let s:schemes.blame = {
      \ 'L': '--%k %v',
      \ 'S': '--%k %v',
      \ 'contents': '--%k %v',
      \ 'date': '--%k %v',
      \ 'commit': '%v',
      \}
function! s:schemes.branch(name, options) abort
  let scheme = {
        \ 'list': '--%k %v',
        \ 'contains': '--%k %v',
        \ 'merged': '--%k %v',
        \ 'no-merged': '--%k %v',
        \ 'branchname': '%v',
        \ 'start-point': '%v',
        \ 'oldbranch': '%v',
        \ 'newbranch': '%v',
        \}
  let args = s:translate_options(a:options, scheme)
  " NOTE:
  " empty strings will be filtered at the end of s:build_args
  return extend(args, [
        \ get(a:options, 'branchname', ''),
        \ get(a:options, 'start-point', ''),
        \ get(a:options, 'oldbranch', ''),
        \ get(a:options, 'newbranch', ''),
        \])
endfunction
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
let s:schemes.commit = {
      \ 'C': '-%k %v',
      \ 'c': '-%k %v',
      \ 'F': '-%k %v',
      \ 'm': '-%k %v',
      \ 't': '-%k %v',
      \}
let s:schemes.clone = {
      \ 'reference': '--%k %v',
      \ 'o': '-%k %v',
      \ 'origin': '--%k %v',
      \ 'b': '-%k %v',
      \ 'branch': '--%k %v',
      \ 'u': '-%k %v',
      \ 'upload-pack': '--%k %v',
      \ 'c': '-%k %v',
      \ 'configig': '--%k %v',
      \ 'depth': '--%k %v',
      \}
let s:schemes.diff = {
      \ 'commit': '%v',
      \}
function! s:schemes.grep(name, options) abort
  let scheme = {
        \ 'max-depth': '--%k %v',
        \ 'A': '-%k %v',
        \ 'B': '-%k %v',
        \ 'C': '-%k %v',
        \ 'f': '-%k %v',
        \}
  let options = s:Dict.omit(a:options, [
        \ 'pattern',
        \ 'commit',
        \ 'directories',
        \])
  let args = s:translate_options(options, scheme)
  let args = extend(args, [
        \ get(a:options, 'pattern', ''),
        \ get(a:options, 'commit', ''),
        \])
  return args
endfunction
let s:schemes.log = {
      \ 'revision-range': '%v',
      \}
let s:schemes['ls-files'] = {
      \ 'x': '-%k %v',
      \ 'X': '-%k %v',
      \ 'exclude': '--%k %v',
      \ 'exclude-from': '--%k %v',
      \ 'exclude-per-directory': '--%k %v',
      \ 'with-tree': '--%k %v',
      \}
let s:schemes['merge-base'] = {
      \ 'fork-point': '--%k %v',
      \ 'commit': '%v',
      \ 'commit1': '%v',
      \ 'commit2': '%v',
      \}
let s:schemes['ls-tree'] = {
      \ 'commit': '%v',
      \}
let s:schemes.show = {
      \ 'object': '%v',
      \}
let s:schemes['rev-parse'] = {
      \ 'default': '--%k %v',
      \ 'prefix': '--%k %v',
      \ 'resolve_git_dir': '--%k %v',
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
