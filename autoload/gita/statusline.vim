let s:save_cpo = &cpo
set cpo&vim
scriptencoding utf8

let s:P = gita#import('Prelude')
let s:S = gita#import('VCS.Git.StatusParser')
let s:format_map = {
      \ 'ln': 'local_name',
      \ 'lb': 'local_branch',
      \ 'rn': 'remote_name',
      \ 'rb': 'remote_branch',
      \ 'og': 'outgoing',
      \ 'ic': 'incoming',
      \ 'nc': 'conflicted',
      \ 'nu': 'unstaged',
      \ 'ns': 'staged',
      \ 'na': 'added',
      \ 'nd': 'deleted',
      \ 'nr': 'renamed',
      \ 'nm': 'modified',
      \}
let s:preset = {
      \ 'branch': '%{|/}ln%lb%{ <> |}rn%{/|}rb',
      \ 'branch_fancy': '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb',
      \ 'status': '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu',
      \ 'traffic': '%{<| }ic%{>|}og',
      \ 'traffic_fancy': '%{￩| }ic%{￫}og',
      \}

function! gita#statusline#get(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  if !gita.enabled
    return {}
  endif
  let meta = gita.git.get_meta()
  let info = {
        \ 'local_name': fnamemodify(gita.git.worktree, ':t'),
        \ 'local_branch': meta.current_branch,
        \ 'remote_name': meta.current_branch_remote,
        \ 'remote_branch': meta.current_remote_branch,
        \ 'outgoing': meta.commits_ahead_of_remote,
        \ 'incoming': meta.commits_behind_remote,
        \}
  let status_count = {
        \ 'conflicted': 0,
        \ 'unstaged': 0,
        \ 'staged': 0,
        \ 'added': 0,
       \ 'deleted': 0,
        \ 'renamed': 0,
        \ 'modified': 0,
        \}
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
  let info = extend(info, status_count)
  return info
endfunction " }}}
function! gita#statusline#format(format, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#get(expr)
  if !gita.enabled
    return ''
  endif
  let cache = gita.git.cache.repository
  if cache.has(a:format) && !gita.git.is_updated('index', 'statusline')
    return cache.get(a:format)
  endif
  let info = get(a:000, 1, gita#statusline#get(expr))
  let formatted = gita#utils#format_string(a:format, s:format_map, info)
  call cache.set(a:format, formatted)
  return formatted
endfunction " }}}
function! gita#statusline#preset(preset_name, ...) abort " {{{
  let format = get(s:preset, a:preset_name, 'Wrong preset name is specified')
  return call('gita#statusline#format', extend([format], a:000))
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
