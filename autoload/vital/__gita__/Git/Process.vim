let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Dict = a:V.import('Data.Dict')
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

" execute({git}, {args}[, {options}])
function! s:execute(git, args, ...) abort
  let options = get(a:000, 0, {})
  let worktree = empty(a:git) ? '' : get(a:git, 'worktree', '')
  let args = (empty(worktree) ? [] : ['-C', worktree]) + a:args
  let args = [s:config.executable] + s:config.arguments + args
  return s:Process.execute(args, options)
endfunction

" shell({git}, {args}[, {options}])
function! s:shell(git, args, ...) abort
  let options = extend({
        \ 'quiet': 0,
        \}, get(a:000, 0, {}))
  let worktree = empty(a:git) ? '' : get(a:git, 'worktree', '')
  let args = (empty(worktree) ? [] : ['-C', worktree]) + a:args
  let args = s:config.arguments + args
  let args = map(args, 'shellescape(v:val)')
  if options.quiet
    " NOTE:
    " interaction mode could not be used with 'quiet' option
    let args += s:Prelude.is_windows()
          \ ? ['>', 'nul']
          \ : ['>', '/dev/null']
  endif
  execute '!' . s:config.executable . ' ' . join(args)
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
