" As of 7.4.122, the system()'s 1st argument is converted internally by Vim.
" Note that Patch 7.4.122 does not convert system()'s 2nd argument and
" return-value. We must convert them manually.
let s:need_trans = v:version < 704 || (v:version == 704 && !has('patch122'))

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \]
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
  return result !=# '' ? result : a:expr
endfunction

function! s:get_last_status(...) abort
  let use_vimproc = get(a:000, 0, s:has_vimproc())
  return use_vimproc
        \ ? vimproc#get_last_status()
        \ : v:shell_error
endfunction

" system({args}[, {input}, {options}])
function! s:system(args, ...) abort
  let input = get(a:000, 0, 0)
  let options = extend({
        \ 'use_vimproc': s:has_vimproc(),
        \ 'timeout': 0,
        \ 'background': 0,
        \}, get(a:000, 0, {}))
  if s:Prelude.is_list(a:args)
    let cmdline = join(map(copy(a:args), 'shellescape(v:val)'), ' ')
  elseif s:Prelude.is_string(a:args)
    let cmdline = a:args
  else
    throw 'vital: Vim.Process: {args} of system() requires to be a List or String.'
  endif
  if s:need_trans
    let cmdline = s:iconv(cmdline, &encoding, 'char')
  endif
  if options.background && (options.use_vimproc || !s:Prelude.is_windows())
    let cmdline = cmdline . '&'
  endif
  let args = [cmdline] + (s:Prelude.is_string(input) ? [input] : [])
  let output = call(options.use_vimproc ? 'vimproc#system' : 'system', args)
  return output
endfunction
