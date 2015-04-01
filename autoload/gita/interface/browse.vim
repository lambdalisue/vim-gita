"******************************************************************************
" vim-gita interface/browse
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:File = gita#util#import('System.File')

function! s:url(...) abort " {{{
  let filename = expand(get(a:000, 0, '%'))
  let bufname = bufname(filename)
  let options = get(a:000, 1, {})
  let gita = gita#get(filename)
  if !gita.enabled
    call gita#util#warn(
          \ 'No git working tree is detected.',
          \)
    return
  elseif !empty(bufname) && getbufvar(bufname, '&buftype') != ''
    call gita#util#warn(
          \ 'Non file buffer is not supported.',
          \)
    return
  endif
  let meta = gita.git.get_meta()
  let data = {}
  let data.path = gita.git.get_relative_path(fnamemodify(filename, ':p'))
  let data.local_branch = meta.current_branch
  let data.local_branch_hash = meta.current_branch_hash
  let data.remote_branch = meta.current_remote_branch
  let data.remote_branch_hash = meta.current_remote_branch_hash
  " get selected region
  if filename != expand('%')
    let data.line_start = ''
    let data.line_end = ''
  elseif has_key(options, '__range__')
    let data.line_start = options.__range__[0]
    let data.line_end = options.__range__[1]
  elseif get(options, 'multiline', 0)
    let data.line_start = getpos("'<")[1]
    let data.line_end = getpos("'>")[1]
  else
    let data.line_start = getpos(".")[1]
    let data.line_end = ''
  endif
  let data.line_end = data.line_start == data.line_end ? '' : data.line_end
  let format_map = {
        \ 'lb': 'local_branch',
        \ 'lh': 'local_branch_hash',
        \ 'rb': 'remote_branch',
        \ 'rh': 'remote_branch_hash',
        \ 'pt': 'path',
        \ 'ls': 'line_start',
        \ 'le': 'line_end',
        \}
  for pattern in g:gita#interface#browse#translation_patterns
    if meta.current_remote_url =~# pattern[0]
      let repl = get(pattern, get(options, 'exact', 0) ? 2 : 1, pattern[1])
      let repl = substitute(meta.current_remote_url, pattern[0], repl, 'g')
      return gita#util#format(repl, format_map, data)
    endif
  endfor
  return ''
endfunction " }}}
function! s:open(...) abort " {{{
  let url = call('s:url', a:000)
  if !empty(url)
    call s:File.open(url)
  endif
  return url
endfunction " }}}

function! gita#interface#browse#url(...) abort " {{{
  return call('s:url', a:000)
endfunction " }}}
function! gita#interface#browse#open(...) abort " {{{
  return call('s:open', a:000)
endfunction " }}}

let s:default_translation_patterns =
      \ [
      \  ['\vgit\@(github\.com):([^/]+)/(.+)%(\.git|)',
      \   'https://\1/\2/\3/blob/%rb/%pt%{#L|}ls%{-L|}le',
      \   'https://\1/\2/\3/blob/%rh/%pt%{?at=|}rb%{#L|}ls%{-L|}le'],
      \  ['\vhttps?://(github\.com)/([^/]+)/(.+)',
      \   'https://\1/\2/\3/blob/%rb/%pt%{#L|}ls%{-L|}le',
      \   'https://\1/\2/\3/blob/%rh/%pt%{?at=|}rb%{#L|}ls%{-L|}le'],
      \  ['\vgit\@(bitbucket\.org):([^/]+)/(.+)%(\.git|)',
      \   'https://\1/\2/\3/src/%rb/%pt%{#cl-|}ls',
      \   'https://\1/\2/\3/src/%rh/%pt%{?at=|}rb%{#cl-|}ls'],
      \  ['\vhttps?://(bitbucket\.org)/([^/]+)/(.+)',
      \   'https://\1/\2/\3/src/%rb/%pt%{#cl-|}ls',
      \   'https://\1/\2/\3/src/%rh/%pt%{?at=|}rb%{#cl-|}ls'],
      \ ]
let g:gita#interface#browse#translation_patterns =
      \ get(g:, 'gita#interface#browse#translation_patterns',
      \   extend(s:default_translation_patterns,
      \     get(g:, 'gita#interface#browse#extra_translation_patterns', []),
      \   )
      \ )

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

