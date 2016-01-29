function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Process = a:V.import('Process')
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
        \ 'Process',
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
        \   ? s:_shellescape(val)
        \   : '',
        \}
  return s:StringExt.format(format, format_map, data)
endfunction
function! s:translate_options(options, scheme) abort
  let args = []
  for key  in sort(keys(a:options))
    if key !~# '^__.\+__$' && key !=# '--'
      let pattern = get(a:scheme, key, '')
      call extend(args, s:StringExt.splitargs(
            \ s:translate_option(key, a:options[key], pattern)
            \))
    endif
  endfor
  if has_key(a:options, '--')
    call add(args, '--')
    for str in a:options['--']
      call add(args, str ==# '-' ? '-' : fnameescape(expand(str)))
    endfor
  endif
  return args
endfunction

" s:build_args({name}[, {options}])
function! s:build_args(name, ...) abort
  let options = get(a:000, 0, {})
  let l:Scheme = get(s:schemes, a:name, {})
  if s:Prelude.is_funcref(l:Scheme)
    let args = l:Scheme(a:name, options)
  else
    let args = s:translate_options(options, l:Scheme)
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
        \ 'input': '',
        \ 'timeout': 0,
        \ 'content': 1,
        \ 'correct': 1,
        \}, get(a:000, 0, {}))
  if empty(config.input)
    unlet config.input
  elseif s:Prelude.is_string(config.input) && config.correct
    let config.input = s:correct_stdin(config.input)
  endif
  let args = [s:config.executable] + s:config.arguments + a:args
  let stdout = s:Process.system(args, s:Dict.pick(config, [
        \ 'input',
        \ 'timeout',
        \ 'use_vimproc',
        \ 'background',
        \]))
  let result = {
        \ 'args': args,
        \ 'stdout': stdout,
        \ 'status': s:Process.get_last_status(),
        \}
  if config.content
    let result['content'] = s:split_stdout(stdout)
  endif
  return result
endfunction

function! s:correct_stdin(stdin) abort
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
  return a:stdin =~# '\r\?\n$' ? a:stdin : a:stdin . "\n"
endfunction

function! s:split_stdout(stdout) abort
  " NOTE:
  " A definition of a TEXT file is "A file that contains characters organized
  " into one or more lines."
  " A definition of a LINE is "A sequence of zero ore more non- <newline>s
  " plus a terminating <newline>"
  " That's why {stdout} always end with <newline> ideally. However, there are
  " some program which does not follow the POSIX rule and a Vim's way to split
  " TEXT into List; split({text}, '\r\?\n', 1); add an extra empty line at the
  " end of List because the end of TEXT ends with <newline> and keepempty=1 is
  " specified. (btw. keepempty=0 cannot be used because it will remove
  " emptylines in head and tail).
  " That's why remove a trailing <newline> before proceeding to 'split'
  " REF:
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
  " http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
  " :help split()
  let stdout = substitute(a:stdout, '\r\?\n$', '', '')
  return split(stdout, '\r\?\n', 1)
endfunction


let s:schemes = {}
let s:schemes.apply = {}
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
