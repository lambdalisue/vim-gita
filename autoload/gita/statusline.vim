let s:save_cpo = &cpo
set cpo&vim
scriptencoding utf8

let s:P = gita#utils#import('Prelude')

" Private functions
function! s:get_info(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#core#get(expr)
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
  let status = gita.git.get_parsed_status(extend({
        \ 'ignore_submodules': 1,
        \}, get(g:, 'gita#statusline#status_options', {}),
        \))
  let status_count = {
        \ 'conflicted': 0,
        \ 'unstaged': 0,
        \ 'staged': 0,
        \ 'added': 0,
        \ 'deleted': 0,
        \ 'renamed': 0,
        \ 'modified': 0,
        \}
  if get(status, 'status', 0) == 0
    let status_count.conflicted = len(status.conflicted)
    let status_count.unstaged = len(status.unstaged)
    let status_count.staged = len(status.staged)
    for ss in status.staged
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
  else
    " something is wrong
    call gita#utils#debugmsg(
          \ 'gita#info%get_info',
          \ 'status.status was not 0',
          \ status,
          \)
  endif
  let info = extend(info, status_count)
  return info
endfunction " }}}
function! s:clear_repository_cache(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#core#get(expr)
  if gita.enabled
    call gita.git.cache.repository.clear()
  endif
endfunction " }}}
function! s:format_string(format, info) abort " {{{
  let format_map = {
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
  return gita#utils#format_string(a:format, format_map, a:info)
endfunction " }}}
function! s:format_string_by_preset(name, info) abort " {{{
  let preset = {
        \ 'branch': '%{|/}ln%lb%{ <> |}rn%{/|}rb',
        \ 'branch_fancy': '⭠ %{|/}ln%lb%{ ⇄ |}rn%{/|}rb',
        \ 'status': '%{!| }nc%{+| }na%{-| }nd%{"| }nr%{*| }nm%{@|}nu',
        \ 'traffic': '%{<| }ic%{>|}og',
        \ 'traffic_fancy': '%{￩| }ic%{￫}og',
        \}
  return s:format_string(get(preset, a:name, ''), a:info)
endfunction " }}}

" Public functions
function! gita#statusline#get(...) abort " {{{
  return call('s:get_info', a:000)
endfunction " }}}
function! gita#statusline#format(format, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  if s:P.is_string(expr)
    let info = s:get_info(expr)
  elseif s:P.is_dict(expr)
    let info = expr
  else
    throw 'vim-gita: a second argument of gita#statusline#format must be a string or dictionary.'
  endif
  return s:format_string(a:format, info)
endfunction " }}}
function! gita#statusline#preset(preset_name, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  if s:P.is_string(expr)
    let info = s:get_info(expr)
  elseif s:P.is_dict(expr)
    let info = expr
  else
    throw 'vim-gita: a second argument of gita#statusline#format must be a string or dictionary.'
  endif
  return s:format_string_by_preset(a:preset_name, info)
endfunction " }}}
function! gita#statusline#clear(...) abort " {{{
  return call('s:clear_repository_cache', a:000)
endfunction " }}}

" Autocmd
augroup vim-gita-info " {{{
  autocmd! *
  " vital-VCS-Git could not detect status change on several git command thus
  " clear cache manually
  autocmd User vim-gita-init-post call s:clear_repository_cache()
  autocmd User vim-gita-fetch-post call s:clear_repository_cache()
  autocmd User vim-gita-commit-post call s:clear_repository_cache()
  autocmd User vim-gita-push-post call s:clear_repository_cache()
  autocmd User vim-gita-pull-post call s:clear_repository_cache()
  autocmd User vim-gita-submodule-post call s:clear_repository_cache()
augroup END " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
