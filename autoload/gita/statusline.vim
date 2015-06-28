let s:save_cpo = &cpo
set cpo&vim
scriptencoding utf8

let s:P = gita#utils#import('Prelude')
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
function! gita#statusline#clear(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#core#get(expr)
  if gita.enabled
    call gita.git.cache.repository.clear()
  endif
endfunction " }}}
function! gita#statusline#format(format, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  if s:P.is_string(expr)
    let info = gita#statusline#get(expr)
  elseif s:P.is_dict(expr)
    let info = expr
  else
    throw 'vim-gita: a second argument of gita#statusline#format must be a string or dictionary.'
  endif
  return gita#utils#format_string(a:format, s:format_map, info)
endfunction " }}}
function! gita#statusline#preset(preset_name, ...) abort " {{{
  let format = get(s:preset, a:preset_name, 'Wrong preset name is specified')
  return call('gita#statusline#format', extend([format], a:000))
endfunction " }}}

augroup vim-gita-statusline
  autocmd! *
  " vital-VCS-Git could not detect status change on several git command thus
  " clear cache manually
  autocmd User vim-gita-init-post call gita#statusline#clear()
  autocmd User vim-gita-submodule-post call gita#statusline#clear()
  autocmd User vim-gita-fetch-post call gita#statusline#clear()
  autocmd User vim-gita-push-post call gita#statusline#clear()
  autocmd User vim-gita-pull-post call gita#statusline#clear()
  autocmd User vim-gita-commit-post call gita#statusline#clear()
augroup END

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
