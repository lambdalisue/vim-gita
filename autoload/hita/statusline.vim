scriptencoding utf8
let s:V = hita#vital()
let s:StringExt = s:V.import('Data.StringExt')
let s:Path = s:V.import('System.Filepath')
let s:Cache = s:V.import('System.Cache.Memory')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')

let s:format_map = {
      \ 'ln': 'local_name',
      \ 'lb': 'local_branch',
      \ 'rn': 'remote_name',
      \ 'rb': 'remote_branch',
      \ 'md': 'mode',
      \}
function! s:format_map.og(data) abort
  " outgoing
  let git = a:data._hita
  return s:GitInfo.count_commits_ahead_of_remote(git)
endfunction
function! s:format_map.ic(data) abort
  " outgoing
  let git = a:data._hita
  return s:GitInfo.count_commits_behind_remote(git)
endfunction
function! s:format_map.nc(data) abort
  " number of conflicted
  if !has_key(a:data, 'conflicted')
    call s:extend_status_count(a:data)
  endif
  return a:data.conflicted
endfunction
function! s:format_map.nu(data) abort
  " number of unstaged
  if !has_key(a:data, 'unstaged')
    call s:extend_status_count(a:data)
  endif
  return a:data.unstaged
endfunction
function! s:format_map.ns(data) abort
  " number of staged
  if !has_key(a:data, 'staged')
    call s:extend_status_count(a:data)
  endif
  return a:data.staged
endfunction
function! s:format_map.na(data) abort
  " number of added
  if !has_key(a:data, 'added')
    call s:extend_status_count(a:data)
  endif
  return a:data.added
endfunction
function! s:format_map.nd(data) abort
  " number of deleted
  if !has_key(a:data, 'deleted')
    call s:extend_status_count(a:data)
  endif
  return a:data.deleted
endfunction
function! s:format_map.nr(data) abort
  " number of renamed
  if !has_key(a:data, 'renamed')
    call s:extend_status_count(a:data)
  endif
  return a:data.renamed
endfunction
function! s:format_map.nm(data) abort
  " number of modified
  if !has_key(a:data, 'modified')
    call s:extend_status_count(a:data)
  endif
  return a:data.modified
endfunction

let s:preset = {}
let s:preset.branch = '%{|/}ln%lb%{ <> |}rn%{/|}rb%{ *|*}md'
let s:preset.branch_fancy = '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb%{ *|*}md'
let s:preset.branch_short = '%{|/}ln%lb%{ <> |}rn'
let s:preset.branch_short_fancy = '⭠ %{|/}ln%lb%{ ⇄ |}rn'
let s:preset.status = '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu'
let s:preset.traffic = '%{<| }ic%{>|}og'
let s:preset.traffic_fancy = '%{￩| }ic%{￫}og'

function! s:extend_status_count(data) abort
  let git = a:data._hita
  let status_count = {
        \ 'conflicted': 0,
        \ 'unstaged': 0,
        \ 'staged': 0,
        \ 'added': 0,
        \ 'deleted': 0,
        \ 'renamed': 0,
        \ 'modified': 0,
        \}
  try
    let result = s:GitProcess.execute(git, 'status', {
          \ 'porcelain': 1,
          \ 'ignore_submodules': 1,
          \})
    let result = s:GitParser.parse_status(result.content)
    let status_count.conflicted = len(result.conflicted)
    let status_count.unstaged = len(result.unstaged)
    let status_count.staged = len(result.staged)
    for status in result.staged
      if status.index ==# 'A'
        let status_count.added += 1
      elseif status.index ==# 'D'
        let status_count.deleted += 1
      elseif status.index ==# 'R'
        let status_count.renamed += 1
      else
        let status_count.modified += 1
      endif
    endfor
    call extend(a:data, status_count)
  catch /^vital: Git[:.]/
    call extend(a:data, {
          \ 'conflicted': 0,
          \ 'unstaged': 0,
          \ 'staged': 0,
          \ 'added': 0,
          \ 'deleted': 0,
          \ 'renamed': 0,
          \ 'modified': 0,
          \})
  endtry
endfunction

function! s:get_format_cache(git) abort
  if !has_key(a:git, '_statusline_format_cache')
    let a:git._statusline_format_cache = s:Cache.new()
  endif
  return a:git._statusline_format_cache
endfunction
function! s:get_uptime_cache(git) abort
  if !has_key(a:git, '_statusline_uptime_cache')
    let a:git._statusline_uptime_cache = s:Cache.new()
  endif
  return a:git._statusline_uptime_cache
endfunction

function! s:is_repository_updated(git) abort
  let uptime_cache = s:get_uptime_cache(a:git)
  let watched = [
        \ 'index', 'HEAD',
        \ 'MERGE_HEAD',
        \ 'CHERRY_PICK_HEAD',
        \ 'REVERT_HEAD',
        \ 'BISECT_LOG',
        \]
  for name in watched
    let cached = uptime_cache.get(name, -1)
    let uptime = s:Git.getftime(a:git, name)
    if uptime > cached
      call uptime_cache.set(name, uptime)
      return 1
    endif
  endfor
  return 0
endfunction

function! s:on_BufWritePre() abort
  let b:_hita_statusline_modified = &modified
endfunction
function! s:on_BufWritePost() abort
  if get(b:, '_hita_statusline_modified', &modified) != &modified
    let git = hita#get()
    if git.is_enabled
      call s:get_format_cache(git).clear()
    endif
  endif
  silent! unlet! b:_hita_statusline_modified
endfunction
function! s:on_HitaStatusModified() abort
  let git = hita#get()
  if git.is_enabled
    call s:get_format_cache(git).clear()
  endif
endfunction

function! hita#statusline#format(format) abort
  try
    let git = hita#get_or_fail()
    let format_cache = s:get_format_cache(git)
    if format_cache.has(a:format) && !s:is_repository_updated(git)
      return format_cache.get(a:format)
    endif
    call format_cache.remove(a:format)
    let local_branch = s:GitInfo.get_local_branch(git)
    let remote_branch = s:GitInfo.get_remote_branch(git)
    let info = {
          \ 'local_name': git.repository_name,
          \ 'local_branch': local_branch.name,
          \ 'local_hashref': local_branch.hash,
          \ 'remote_name': remote_branch.remote,
          \ 'remote_branch': remote_branch.name,
          \ 'remote_hashref': remote_branch.hash,
          \ 'mode': s:GitInfo.get_current_mode(git),
          \ '_hita': git,
          \}
    let text = s:StringExt.format(a:format, s:format_map, info)
    call format_cache.set(a:format, text)
    return text
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    return ''
  endtry
endfunction

function! hita#statusline#preset(name) abort
  if !has_key(s:preset, a:name)
    call s:Prompt.error(printf(
          \ 'vim-hita: statusline: A preset "%s" is not found.',
          \ a:name,
          \))
    return ''
  endif
  return hita#statusline#format(s:preset[a:name])
endfunction

augroup vim_hita_internal_statusline_clear_cache
  autocmd! *
  autocmd BufWritePre  * call s:on_BufWritePre()
  autocmd BufWritePost * call s:on_BufWritePost()
  autocmd User HitaStatusModified call s:on_HitaStatusModified()
augroup END
