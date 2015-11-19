let s:save_cpoptions = &cpoptions
set cpoptions&vim
scriptencoding utf8

let s:P = gita#import('System.Filepath')
let s:S = gita#import('VCS.Git.StatusParser')
let s:format_map = {
      \ 'ln': 'local_name',
      \ 'lb': 'local_branch',
      \ 'rn': 'remote_name',
      \ 'rb': 'remote_branch',
      \ 'md': 'mode',
      \}
function! s:format_map.og(data) abort " {{{
  " outgoing
  let gita = a:data._gita
  return gita.git.count_commits_ahead_of_remote()
endfunction " }}}
function! s:format_map.ic(data) abort " {{{
  " outgoing
  let gita = a:data._gita
  return gita.git.count_commits_behind_remote()
endfunction " }}}
function! s:format_map.nc(data) abort " {{{
  " number of conflicted
  if !has_key(a:data, 'conflicted')
    call s:extend_status_count(a:data)
  endif
  return a:data.conflicted
endfunction " }}}
function! s:format_map.nu(data) abort " {{{
  " number of unstaged
  if !has_key(a:data, 'unstaged')
    call s:extend_status_count(a:data)
  endif
  return a:data.unstaged
endfunction " }}}
function! s:format_map.ns(data) abort " {{{
  " number of staged
  if !has_key(a:data, 'staged')
    call s:extend_status_count(a:data)
  endif
  return a:data.staged
endfunction " }}}
function! s:format_map.na(data) abort " {{{
  " number of added
  if !has_key(a:data, 'added')
    call s:extend_status_count(a:data)
  endif
  return a:data.added
endfunction " }}}
function! s:format_map.nd(data) abort " {{{
  " number of deleted
  if !has_key(a:data, 'deleted')
    call s:extend_status_count(a:data)
  endif
  return a:data.deleted
endfunction " }}}
function! s:format_map.nr(data) abort " {{{
  " number of renamed
  if !has_key(a:data, 'renamed')
    call s:extend_status_count(a:data)
  endif
  return a:data.renamed
endfunction " }}}
function! s:format_map.nm(data) abort " {{{
  " number of modified
  if !has_key(a:data, 'modified')
    call s:extend_status_count(a:data)
  endif
  return a:data.modified
endfunction " }}}

let s:preset = {}
function! s:preset.branch(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('branch') || s:is_updated(gita, ['HEAD', 'config'])
    let format = '%{|/}ln%lb%{ <> |}rn%{/|}rb%{ *|*}md'
    call cache.set('branch', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "branch" cache is updated')
  endif
  return cache.get('branch')
endfunction " }}}
function! s:preset.branch_fancy(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('branch_fancy') || s:is_updated(gita, ['HEAD', 'config'])
    let format = '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb%{ *|*}md'
    call cache.set('branch_fancy', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "branch_fancy" cache is updated')
  endif
  return cache.get('branch_fancy')
endfunction " }}}
function! s:preset.branch_short(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('branch_short') || s:is_updated(gita, ['HEAD', 'config'])
    let format = '%{|/}ln%lb%{ <> |}rn'
    call cache.set('branch_short', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "branch_short" cache is updated')
  endif
  return cache.get('branch_short')
endfunction " }}}
function! s:preset.branch_short_fancy(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('branch_short_fancy') || s:is_updated(gita, ['HEAD', 'config'])
    let format = '⭠ %{|/}ln%lb%{ ⇄ |}rn'
    call cache.set('branch_short_fancy', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "branch_short_fancy" cache is updated')
  endif
  return cache.get('branch_short_fancy')
endfunction " }}}
function! s:preset.status(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('status') || s:is_updated(gita, ['index'])
    let format = '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu'
    call cache.set('status', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "status" cache is updated')
  endif
  return cache.get('status')
endfunction " }}}
function! s:preset.traffic(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('traffic') || s:is_updated(gita, ['index', 'config', 'HEAD'])
    let format = '%{<| }ic%{>|}og'
    call cache.set('traffic', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "traffic" cache is updated')
  endif
  return cache.get('traffic')
endfunction " }}}
function! s:preset.traffic_fancy(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  let cache = gita.git.cache.repository
  if !cache.has('traffic_fancy') || s:is_updated(gita, ['index', 'config', 'HEAD'])
    let format = '%{￩| }ic%{￫}og'
    call cache.set('traffic_fancy', gita#statusline#format(format, expr))
    call gita#utils#prompt#debug('statusline "traffic_fancy" cache is updated')
  endif
  return cache.get('traffic_fancy')
endfunction " }}}

function! s:extend_status_count(data) abort " {{{
  let gita = a:data._gita
  let status_count = {
        \ 'conflicted': 0,
        \ 'unstaged': 0,
        \ 'staged': 0,
        \ 'added': 0,
        \ 'deleted': 0,
        \ 'renamed': 0,
        \ 'modified': 0,
        \}
  if gita.git._is_readable('index')
    let result = gita#features#status#exec_cached({
          \ 'porcelain': 1,
          \ 'ignore_submodules': 1,
          \}, {
          \ 'echo': '',
          \})
    let status = s:S.parse(result.stdout, { 'fail_silently': 1 })
    if get(status, 'status', 0) == 0
      let status_count.conflicted = len(status.conflicted)
      let status_count.unstaged = len(status.unstaged)
      let status_count.staged = len(status.staged)
      for ss in status.staged
        if ss.index ==# 'A'
          let status_count.added += 1
        elseif ss.index ==# 'D'
          let status_count.deleted += 1
        elseif ss.index ==# 'R'
          let status_count.renamed += 1
        else
          let status_count.modified += 1
        endif
      endfor
    endif
  endif
  call extend(a:data, status_count)
endfunction " }}}
function! s:is_updated(gita, ...) abort " {{{
  let watched = get(a:000, 0, [
        \ 'index',
        \ 'MERGE_HEAD',
        \ 'CHERRY_PICK_HEAD',
        \ 'REVERT_HEAD',
        \ 'BISECT_LOG',
        \])
  for name in watched
    if a:gita.git.is_updated(name)
      return 1
    endif
  endfor
  return 0
endfunction " }}}

function! gita#statusline#format(format, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  if !gita.enabled
    return ''
  endif
  let meta = gita.git.get_meta()
  let info = {
        \ 'local_name': meta.local.name,
        \ 'local_branch': meta.local.branch_name,
        \ 'remote_name': meta.remote.name,
        \ 'remote_branch': meta.remote.branch_name,
        \ 'mode': gita.git.get_mode(),
        \ 'timestamp': gita.git.cache.repository.get('timestamp', ''),
        \ '_gita': gita,
        \}
  let formatted = gita#utils#format_string(a:format, s:format_map, info)
  return formatted
endfunction " }}}
function! gita#statusline#preset(preset_name, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  if !gita.enabled
    return ''
  endif
  if !has_key(s:preset, a:preset_name)
    call gita#utils#prompt#error(printf('A preset "%s" is not found.', a:preset_name))
    return ''
  endif
  return call(s:preset[a:preset_name], a:000, s:preset)
endfunction " }}}
function! gita#statusline#debug(...) abort " {{{
  if !g:gita#debug
    return ''
  endif
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  if !gita.enabled
    return ''
  endif
  let cache = gita.git.cache.repository
  return printf('gita.cache: %s', get(cache, '_timestamp', ''))
endfunction " }}}

function! s:ac_BufWritePre() abort
  let b:_gita_clear_cache = &modified
endfunction
function! s:ac_BufWritePost() abort
  if get(b:, '_gita_clear_cache')
    call gita#clear_cache()
  endif
  silent! unlet! b:_gita_clear_cache
endfunction

augroup vim-gita-statusline-clear-cache
  autocmd! *
  autocmd BufWritePre  * call s:ac_BufWritePre()
  autocmd BufWritePost * call s:ac_BufWritePost()
augroup END

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
