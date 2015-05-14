let s:save_cpo = &cpo
set cpo&vim


" Private
function! s:get_status_header(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#core#get(expr)
  let meta = gita.git.get_meta()
  let name = fnamemodify(gita.git.worktree, ':t')
  let branch = meta.current_branch
  let remote_name = meta.current_branch_remote
  let remote_branch = meta.current_remote_branch
  let outgoing = gita.git.count_commits_ahead_of_remote()
  let incoming = gita.git.count_commits_behind_remote()
  let is_connected = !(empty(remote_name) || empty(remote_branch))

  let lines = []
  if is_connected
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s` <> `%s/%s`',
          \   name, branch, remote_name, remote_branch
          \))
    if outgoing > 0 && incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead and %d commit(s) behind of `%s/%s`',
            \   outgoing, incoming, remote_name, remote_branch,
            \))
    elseif outgoing > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead of `%s/%s`',
            \   outgoing, remote_name, remote_branch,
            \))
    elseif incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) behind `%s/%s`',
            \   incoming, remote_name, remote_branch,
            \))
    endif
  else
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s`',
          \   name, branch
          \))

  endif
  return lines
endfunction " }}}
function! s:get_statuses_map() abort " {{{
  return get(b:, '_gita_statuses_map', {})
endfunction " }}}
function! s:set_statuses_map(statuses_map) abort " {{{
  let b:_gita_statuses_map = deepcopy(a:statuses_map)
endfunction " }}}
function! s:get_selected_statuses(fline, lline) abort " {{{
  let statuses_map = s:get_statuses_map()
  let selected_statuses = []
  for n in range(a:fline, a:lline)
    let status = get(statuses_map, getline(n), {})
    if !empty(status)
      call add(selected_statuses, status)
    endif
  endfor
  return selected_statuses
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  return empty(s:get_selected_statuses(a:firstline, a:firstline)) ? a:lhs : a:rhs
endfunction " }}}

function! s:action_open(statuses, options) abort " {{{
  for status in a:statuses
    let path = get(a:status, 'path2', get(a:status, 'path', ''))
    let opener = get(a:options, 'opener', 'edit')
    call gita#utils#buffer#open(path, '', {
          \ 'opener': opener,
          \})
  endfor
endfunction " }}}
function! s:action_help(statuses, options) abort " {{{
  let name = a:options.name
  call gita#utils#help#toggle(name)
endfunction " }}}


" Public
function! gita#utils#status#get_status_header(...) abort " {{{
  return call('s:get_status_header', a:000)
endfunction " }}}
function! gita#utils#status#set_statuses_map(...) abort " {{{
  return call('s:set_statuses_map', a:000)
endfunction " }}}
function! gita#utils#status#get_selected_statuses(...) abort " {{{
  return call('s:get_selected_statuses', a:000)
endfunction " }}}
function! gita#utils#status#smart_map(...) abort " {{{
  return call('s:smart_map', a:000)
endfunction " }}}

function! gita#utils#status#action_open(...) abort " {{{
  call call('s:action_open', a:000)
endfunction " }}}
function! gita#utils#status#action_help(...) abort " {{{
  call call('s:action_help', a:000)
endfunction " }}}
