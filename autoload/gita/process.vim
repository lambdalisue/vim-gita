let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:translate(key, options, scheme) abort
  let value = a:options[a:key]
  if s:Prelude.is_list(value)
    return map(value, 's:translate(a:key, { a:key : v:val }, a:scheme)')
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

function! s:strip_quotes(value) abort
  let value = s:ArgumentParser.strip_quotes(a:value)
  if value =~# '^--\?\w\+=["''].*["'']$'
    let value = substitute(value, '^\(--\?\w\+=\)["'']\(.*\)["'']$', '\1\2', '')
  endif
  return value
endfunction

function! gita#process#splitargs(args) abort
  let args = s:ArgumentParser.splitargs(a:args)
  let args = map(args, 's:strip_quotes(v:val)')
  return args
endfunction

function! gita#process#execute(git, args, ...) abort
  let options = extend({
        \ 'quiet': 0,
        \ 'fail_silently': 0,
        \ 'success_status': 0,
        \}, get(a:000, 0, {}))
  let args = filter(copy(a:args), '!empty(v:val)')
  let result = s:GitProcess.execute(a:git, args, s:Dict.omit(options, [
        \ 'quiet', 'fail_silently', 'success_status',
        \]))
  let is_success = result.status == options.success_status
  if !options.fail_silently && !is_success
    call s:GitProcess.throw(result)
  elseif !options.quiet
    call s:Prompt.title(printf('%s: %s',
          \ is_success ? 'OK' : 'Fail',
          \ join(result.args),
          \))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

call gita#define_variables('process', {
      \ 'executable': 'git',
      \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
      \})

call s:GitProcess.set_config({
      \ 'executable': g:gita#process#executable,
      \ 'arguments':  g:gita#process#arguments,
      \})
