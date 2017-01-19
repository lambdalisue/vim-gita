let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:String = s:V.import('Data.String')
let s:Console = s:V.import('Vim.Console')
let s:Process = s:V.import('System.Process')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:translate(key, options, scheme) abort
  let value = a:options[a:key]
  if s:Prelude.is_list(value)
    return s:List.flatten(map(
          \ copy(value),
          \ 's:translate(a:key, { a:key : v:val }, a:scheme)'
          \))
  elseif s:Prelude.is_number(value)
    return value ? [(len(a:key) == 1 ? '-' : '--') . a:key] : []
  else
    let value = value =~# '\s' ? printf("'%s'", value) : value
    return gita#process#splitargs(gita#util#formatter#format(
          \ a:scheme,
          \ { 'k': 'key', 'v': 'val' },
          \ { 'key': a:key, 'val': value },
          \))
  endif
endfunction

function! s:strip_quotes(value) abort
  let value = s:ArgumentParser.strip_quotes(a:value)
  if value =~# '^--\?\w\+=["''].*["'']$'
    let value = substitute(value, '^\(--\?\w\+=\)["'']\(.*\)["'']$', '\1\2', '')
  endif
  return value
endfunction

function! gita#process#args_from_options(options, schemes) abort
  let args = []
  for key in sort(keys(a:schemes))
    if !has_key(a:options, key)
      continue
    endif
    let scheme = s:Prelude.is_string(a:schemes[key])
          \ ? a:schemes[key]
          \ : len(key) == 1 ? '-%k%v' : '--%k%{=}v'
    call extend(args, s:translate(key, a:options, scheme))
  endfor
  return args
endfunction

function! gita#process#splitargs(args) abort
  let args = s:ArgumentParser.splitargs(a:args)
  let args = map(args, 's:strip_quotes(v:val)')
  let args = map(args, 's:String.unescape(v:val, '' '')')
  return args
endfunction

function! gita#process#execute(git, args, ...) abort
  call s:GitProcess.set_config({
        \ 'executable': g:gita#process#executable,
        \ 'arguments':  g:gita#process#arguments,
        \})
  let options = extend({
        \ 'quiet': 0,
        \ 'fail_silently': 0,
        \ 'clients': g:gita#process#clients,
        \}, get(a:000, 0, {}))
  let options = extend(copy(g:gita#process#options), options)
  let result = s:GitProcess.execute(a:git, a:args, s:Dict.omit(options, [
        \ 'quiet', 'fail_silently',
        \]))
  if !options.fail_silently && !result.success
    call s:GitProcess.throw(result)
  elseif !options.quiet
    call s:Console.info(printf('%s: %s',
          \ result.success ? 'OK' : 'Fail',
          \ join(result.args),
          \))
    echo join(result.content, "\n")
  endif
  return result
endfunction

function! gita#process#shell(git, args) abort
  call s:GitProcess.set_config({
        \ 'executable': g:gita#process#executable,
        \ 'arguments':  g:gita#process#arguments,
        \})
  call s:GitProcess.shell(a:git, a:args)
endfunction

call gita#define_variables('process', {
      \ 'executable': 'git',
      \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
      \ 'options': {},
      \ 'clients': [
      \   'System.Process.Job',
      \   'System.Process.Vimproc',
      \   'System.Process.System',
      \ ]
      \})

" Enable System.Process.Job
call s:Process.register('System.Process.Job')
