let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Dict = a:V.import('Data.Dict')
  let s:StringExt = a:V.import('Data.StringExt')
  let s:Process = a:V.import('System.Process')
  let s:config = {
        \ 'executable': 'git',
        \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
        \}
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Data.Dict',
        \ 'Data.StringExt',
        \ 'System.Process',
        \]
endfunction

function! s:get_config() abort
  return copy(s:config)
endfunction
function! s:set_config(config) abort
  call extend(s:config, s:Dict.pick(a:config, [
        \ 'executable',
        \ 'arguments',
        \]))
endfunction

function! s:throw(msg_or_result) abort
  if s:Prelude.is_dict(a:msg_or_result)
    let msg = printf("%s: %s\n%s",
          \ a:msg_or_result.success ? 'OK' : 'Fail',
          \ join(a:msg_or_result.args), a:msg_or_result.output,
          \)
  else
    let msg = a:msg_or_result
  endif
  throw 'vital: Git.Process: ' . msg
endfunction

function! s:enclose_if_required(value) abort
  return a:value =~# '\s' ? printf("'%s'", a:value) : a:value
endfunction

function! s:translate(key, options, ...) abort
  let scheme = get(a:000, 0, len(a:key) == 1 ? '-%k%v' : '--%k%{=}v')
  if !has_key(a:options, a:key)
    return []
  endif
  let value = a:options[a:key]
  if s:Prelude.is_list(value)
    return map(value, 's:translate(a:key, { a:key : v:val }, scheme)')
  elseif s:Prelude.is_number(value)
    return value ? [(len(a:key) == 1 ? '-' : '--') . a:key] : []
  else
  return s:StringExt.splitargs(s:StringExt.format(
        \ scheme,
        \ { 'k': 'key', 'v': 'val' },
        \ { 'key': a:key, 'val': s:enclose_if_required(value) },
        \))
  endif
endfunction

" execute({git}, {args}[, {options}])
function! s:execute(git, args, ...) abort
  let options = get(a:000, 0, {})
  let worktree = empty(a:git) ? '' : get(a:git, 'worktree', '')
  let args = (empty(worktree) ? [] : ['-C', worktree]) + a:args
  let args = [s:config.executable] + s:config.arguments + args
  return s:Process.execute(
        \ filter(args, '!empty(v:val)'),
        \ options,
        \)
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
