scriptencoding utf8
let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Cache = s:V.import('System.Cache.Memory')
let s:Console = s:V.import('Vim.Console')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')

let s:format_map = {}
function! s:format_map.md(data) abort
  " mode name
  return gita#statusline#get_current_mode(a:data._git)
endfunction
function! s:format_map.ln(data) abort
  " local repository name
  return a:data._git.repository_name
endfunction
function! s:format_map.lb(data) abort
  " local branch name
  if !has_key(a:data, 'local_branch')
    call s:extend_local_branch(a:data)
  endif
  return a:data.local_branch.name
endfunction
function! s:format_map.lh(data) abort
  " local branch hashref
  if !has_key(a:data, 'local_branch')
    call s:extend_local_branch(a:data)
  endif
  return a:data.local_branch.hash
endfunction
function! s:format_map.rn(data) abort
  " remote repository name
  if !has_key(a:data, 'remote_branch')
    call s:extend_remote_branch(a:data)
  endif
  return a:data.remote_branch.remote
endfunction
function! s:format_map.rb(data) abort
  " local branch name
  if !has_key(a:data, 'remote_branch')
    call s:extend_remote_branch(a:data)
  endif
  return a:data.remote_branch.name
endfunction
function! s:format_map.rh(data) abort
  " local branch hashref
  if !has_key(a:data, 'remote_branch')
    call s:extend_remote_branch(a:data)
  endif
  return a:data.remote_branch.hash
endfunction
function! s:format_map.og(data) abort
  " outgoing
  if !has_key(a:data, 'outgoing')
    call s:extend_traffic_count(a:data)
  endif
  return a:data.outgoing
endfunction
function! s:format_map.ic(data) abort
  " incoming
  if !has_key(a:data, 'incoming')
    call s:extend_traffic_count(a:data)
  endif
  return a:data.incoming
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

function! s:extend_local_branch(data) abort
  call extend(a:data, {
        \ 'local_branch': gita#statusline#get_local_branch(a:data._git),
        \})
endfunction
function! s:extend_remote_branch(data) abort
  call extend(a:data, {
        \ 'remote_branch': gita#statusline#get_remote_branch(a:data._git),
        \})
endfunction
function! s:extend_status_count(data) abort
  call extend(a:data, gita#statusline#get_status_count(a:data._git))
endfunction
function! s:extend_traffic_count(data) abort
  call extend(a:data, gita#statusline#get_traffic_count(a:data._git))
endfunction

let s:preset = {}
let s:preset.branch = '%{|/}ln%lb%{ <> |}rn%{/|}rb%{ *|*}md'
let s:preset.branch_fancy = '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb%{ *|*}md'
let s:preset.branch_short = '%{|/}ln%lb%{ <> |}rn'
let s:preset.branch_short_fancy = '⭠ %{|/}ln%lb%{ ⇄ |}rn'
let s:preset.status = '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu'
let s:preset.traffic = '%{<| }ic%{>|}og'
let s:preset.traffic_fancy = '%{￩| }ic%{￫}og'

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
    let cached = uptime_cache.get(name, [])
    let exists = s:Git.filereadable(a:git, name)
    let uptime = s:Git.getftime(a:git, name)
    if empty(cached) || cached[0] != exists || cached[1] < uptime
      call uptime_cache.set(name, [exists, uptime])
      return 1
    endif
  endfor
  return 0
endfunction

function! s:on_GitaStatusModifiedPre() abort
  let git = gita#core#get()
  call s:get_format_cache(git).clear()
  if !git.is_enabled
    return
  endif
  " NOTE:
  " If working tree files are changed, it is not possible to detect changes
  " from Vital.Git cache mechanisms so remove a cache for status count while
  " status count may change when working tree files are changed.
  call git.repository_cache.remove('gita#statusline#get_status_count:[''index'']')
  " NOTE:
  " If 'index' is pushed to the remote, it is not possible to detec changes
  " from Vital.Git cache mechanisms so remove a cache for traffic count while
  " traffic count may change when push is performed
  call git.repository_cache.remove('gita#statusline#get_traffic_count:[''index'']')
endfunction

function! gita#statusline#format(format) abort
  try
    let git = gita#core#get_or_fail()
    let format_cache = s:get_format_cache(git)
    if format_cache.has(a:format) && !s:is_repository_updated(git)
      return format_cache.get(a:format)
    endif
    call format_cache.remove(a:format)
    let info = { '_git': git }
    let text = gita#util#formatter#format(a:format, s:format_map, info)
    call format_cache.set(a:format, text)
    return text
  catch /^\%(vital: Git[:.]\|gita:\)/
    return ''
  endtry
endfunction
function! gita#statusline#preset(name) abort
  if !has_key(s:preset, a:name)
    call s:Console.error(printf(
          \ 'gita: statusline: A preset "%s" is not found.',
          \ a:name,
          \))
    return ''
  endif
  return gita#statusline#format(s:preset[a:name])
endfunction

function! gita#statusline#get_current_mode(git) abort
  return s:GitInfo.get_current_mode(a:git)
endfunction
function! gita#statusline#get_local_branch(git) abort
  let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
  let content = s:Git.get_cache_content(a:git, 'HEAD', slug, {})
  if empty(content)
    let content = s:GitInfo.get_local_branch(a:git)
    call s:Git.set_cache_content(a:git, 'HEAD', slug, content)
  endif
  return content
endfunction
function! gita#statusline#get_remote_branch(git) abort
  let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
  let content = s:Git.get_cache_content(a:git, ['HEAD', 'config', 'packed-refs'], slug, {})
  if empty(content)
    let content = s:GitInfo.get_remote_branch(a:git)
    call s:Git.set_cache_content(a:git, ['HEAD', 'config', 'packed-refs'], slug, content)
  endif
  return content
endfunction
function! gita#statusline#get_traffic_count(git) abort
  let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
  let content = s:Git.get_cache_content(a:git, 'index', slug, {})
  if empty(content)
    let content = {
          \ 'incoming': 0,
          \ 'outgoing': 0,
          \}
    try
      let content.incoming = s:GitInfo.count_commits_behind_remote(a:git)
      let content.outgoing = s:GitInfo.count_commits_ahead_of_remote(a:git)
    catch /^vital: Git[:.]/
      " fail silently
    endtry
    call s:Git.set_cache_content(a:git, 'index', slug, content)
  endif
  return content
endfunction
function! gita#statusline#get_status_count(git) abort
  let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
  let content = s:Git.get_cache_content(a:git, 'index', slug, {})
  if empty(content)
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
      let git = gita#core#get_or_fail()
      let result = s:GitParser.parse_status(gita#process#execute(
            \ git,
            \ ['status', '--porcelain', '--ignore-submodules'],
            \ { 'quiet': 1 },
            \).content)
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
      let content = status_count
    catch /^vital: Git[:.]/
      let content = {
            \ 'conflicted': 0,
            \ 'unstaged': 0,
            \ 'staged': 0,
            \ 'added': 0,
            \ 'deleted': 0,
            \ 'renamed': 0,
            \ 'modified': 0,
            \}
    endtry
    call s:Git.set_cache_content(a:git, 'index', slug, content)
  endif
  return content
endfunction

augroup gita_internal_statusline
  autocmd! *
  autocmd User GitaStatusModifiedPre call s:on_GitaStatusModifiedPre()
augroup END
