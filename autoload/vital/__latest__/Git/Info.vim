function! s:_vital_loaded(V) abort
  let s:Dict = a:V.import('Data.Dict')
  let s:List = a:V.import('Data.List')
  let s:Path = a:V.import('System.Filepath')
  let s:INI = a:V.import('Text.INI')
  let s:Git = a:V.import('Git')
  let s:GitProcess = a:V.import('Git.Process')

  " obsolete
  let s:Prelude = a:V.import('Prelude')
  let s:StringExt = a:V.import('Data.StringExt')
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Data.Dict',
        \ 'Data.List',
        \ 'System.Filepath',
        \ 'Text.INI',
        \ 'Git',
        \ 'Git.Process',
        \]
endfunction

function! s:get_head(git) abort
  return s:Git.readline(a:git, 'HEAD')
endfunction
function! s:get_fetch_head(git) abort
  return s:Git.readline(a:git, 'FETCH_HEAD')
endfunction
function! s:get_orig_head(git) abort
  return s:Git.readline(a:git, 'ORIG_HEAD')
endfunction
function! s:get_merge_head(git) abort
  return s:Git.readline(a:git, 'MERGE_HEAD')
endfunction
function! s:get_cherry_pick_head(git) abort
  return s:Git.readline(a:git, 'CHERRY_PICK_HEAD')
endfunction
function! s:get_revert_head(git) abort
  return s:Git.readline(a:git, 'REVERT_HEAD')
endfunction
function! s:get_bisect_log(git) abort
  return s:Git.readline(a:git, 'BISECT_LOG')
endfunction
function! s:get_rebase_merge_head(git) abort
  return s:Git.readline(a:git, 'rebase-merge', 'head-name')
endfunction
function! s:get_rebase_merge_step(git) abort
  return s:Git.readline(a:git, 'rebase-merge', 'msgnum')
endfunction
function! s:get_rebase_merge_total(git) abort
  return s:Git.readline(a:git, 'rebase-merge', 'end')
endfunction
function! s:get_rebase_apply_head(git) abort
  return s:Git.readline(a:git, 'rebase-apply', 'head-name')
endfunction
function! s:get_rebase_apply_step(git) abort
  return s:Git.readline(a:git, 'rebase-apply', 'next')
endfunction
function! s:get_rebase_apply_total(git) abort
  return s:Git.readline(a:git, 'rebase-apply', 'last')
endfunction
function! s:get_commit_editmsg(git) abort
  return s:Git.readfile(a:git, 'COMMIT_EDITMSG')
endfunction
function! s:get_merge_msg(git) abort
  return s:Git.readfile(a:git, 'MERGE_MSG')
endfunction

function! s:is_merging(git) abort
  return s:Git.filereadable(a:git, 'MERGE_HEAD')
endfunction
function! s:is_cherry_picking(git) abort
  return s:Git.filereadable(a:git, 'CHERRY_PICK_HEAD')
endfunction
function! s:is_reverting(git) abort
  return s:Git.filereadable(a:git, 'REVERT_HEAD')
endfunction
function! s:is_bisecting(git) abort
  return s:Git.filereadable(a:git, 'BISECT_LOG')
endfunction
function! s:is_rebase_merging(git) abort
  return s:Git.isdirectory(a:git, 'rebase-merge')
endfunction
function! s:is_rebase_merging_interactive(git) abort
  return s:Git.filereadable(a:git, 'rebase-merge', 'interactive')
endfunction
function! s:is_rebase_applying(git) abort
  return s:Git.isdirectory(a:git, 'rebase-apply')
endfunction
function! s:is_rebase_applying_rebase(git) abort
  return s:Git.filereadable(a:git, 'rebase-apply', 'rebasing')
endfunction
function! s:is_rebase_applying_am(git) abort
  return s:Git.filereadable(a:git, 'rebase-apply', 'applying')
endfunction

function! s:get_current_mode(git) abort
  " https://github.com/git/git/blob/dd160d7/contrib/completion/git-prompt.sh#L391-L460
  if s:is_rebase_merging(a:git)
    let step  = s:get_rebase_merge_step(a:git)
    let total = s:get_rebase_merge_total(a:git)
    if s:is_rebase_merging_interactive(a:git)
      return printf('REBASE-i %d/%d', step, total)
    else
      return printf('REBASE-m %d/%d', step, total)
    endif
  else
    if s:is_rebase_applying(a:git)
      let step  = s:get_rebase_apply_step(a:git)
      let total = s:get_rebase_apply_total(a:git)
      if s:is_rebase_applying_rebase(a:git)
        return printf('REBASE %d/%d', step, total)
      elseif s:is_rebase_applying_am(a:git)
        return printf('AM %d/%d', step, total)
      else
        return printf('AM/REBASE %d/%d', step, total)
      endif
    elseif s:is_merging(a:git)
      return 'MERGING'
    elseif s:is_cherry_picking(a:git)
      return 'CHERRY-PICKING'
    elseif s:is_reverting(a:git)
      return 'REVERTING'
    elseif s:is_bisecting(a:git)
      return 'BISECTING'
    endif
  endif
  return ''
endfunction


" *** Time consuming *********************************************************
function! s:get_repository_config(git) abort
  let filename = s:Path.join(a:git.repository, 'config')
  if filereadable(filename)
    return s:INI.parse_file(filename)
  endif
  return {}
endfunction
function! s:get_branch_remote(config, local_branch) abort
  " a name of remote which the {local_branch} connect
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  return get(section, 'remote', '')
endfunction
function! s:get_branch_merge(config, local_branch, ...) abort
  " a branch name of remote which {local_branch} connect
  let truncate = get(a:000, 0, 0)
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  let merge = get(section, 'merge', '')
  return truncate ? substitute(merge, '\v^refs/heads/', '', '') : merge
endfunction
function! s:get_remote_fetch(config, remote) abort
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'fetch', '')
endfunction
function! s:get_remote_url(config, remote) abort
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'url', '')
endfunction
function! s:get_comment_char(config, ...) abort
  let default = get(a:000, 0, '#')
  let section = get(a:config, 'core', {})
  if empty(section)
    return default
  endif
  return get(section, 'commentchar', default)
endfunction


function! s:resolve_ref(git, ref) abort
  let content = s:Git.readline(a:git, a:ref)
  if content =~# '^ref:\s'
    " recursively resolve ref
    return s:resolve_ref(a:git, substitute(content, '^ref:\s', '', ''))
  elseif empty(content)
    " ref is missing in traditional directory, the ref should be written in
    " packed-ref then
    let filter_code = printf(
          \ 'v:val[0] !=# "#" && v:val[-%d:] ==# a:ref',
          \ len(a:ref)
          \)
    let packed_refs = filter(
          \ s:Git.readfile(a:git, 'packed-refs'),
          \ filter_code
          \)
    let content = get(split(get(packed_refs, 0, '')), 0, '')
  endif
  return content
endfunction
function! s:get_local_hash(git, branch) abort
  if a:branch =~# 'HEAD'
    let HEAD = s:get_head(a:git)
    let ref = substitute(HEAD, '^ref:\s', '', '')
  else
    let ref = s:Path.join('refs', 'heads', a:branch)
  endif
  return s:resolve_ref(a:git, ref)
endfunction
function! s:get_remote_hash(git, remote, branch) abort
  let ref = s:Path.join('refs', 'remotes', a:remote, a:branch)
  return s:resolve_ref(a:git, ref)
endfunction
function! s:get_local_branch(git) abort
  let head = s:get_head(a:git)
  let branch_name = head =~# 'refs/heads/'
        \ ? matchstr(head, 'refs/heads/\zs.\+$')
        \ : head[:7]
  let branch_hash = s:get_local_hash(a:git, branch_name)
  return {
        \ 'name': branch_name,
        \ 'hash': branch_hash,
        \}
endfunction
function! s:get_remote_branch(git) abort
  let config = s:get_repository_config(a:git)
  if empty(config)
    return { 'name': '', 'hash': '', 'url': '' }
  endif
  let local = s:get_local_branch(a:git)
  let merge = s:get_branch_merge(config, local.name)
  let remote = s:get_branch_remote(config, local.name)
  let remote_url = s:get_remote_url(config, remote)
  let branch_name = merge =~# 'refs/heads/'
        \ ? matchstr(merge, 'refs/heads/\zs.\+$')
        \ : merge[:7]
  let branch_hash = s:get_remote_hash(a:git, remote, branch_name)
  return {
        \ 'remote': remote,
        \ 'name': branch_name,
        \ 'hash': branch_hash,
        \ 'url': remote_url,
        \}
endfunction


" *** External process *******************************************************
function! s:get_git_version() abort
  let result = s:GitProcess.execute({}, ['--version'])
  if result.success
    return matchstr(result.output, '^git version \zs.*$')
  else
    return '0.0.0'
  endif
endfunction

function! s:get_last_commitmsg(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let result = s:GitProcess.execute(a:git, [
        \ 'log', '-1', '--pretty=%B',
        \])
  if !result.success
    if options.fail_silently
      return []
    endif
    call s:GitProcess.throw(result)
  endif
  return result.content
endfunction

function! s:count_commits_ahead_of_remote(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let result = s:GitProcess.execute(a:git, [
        \ 'log', '--oneline', '@{upstream}..'
        \])
  if !result.success
    if options.fail_silently
      return 0
    endif
    call s:GitProcess.throw(result)
  endif
  return len(filter(result.content, '!empty(v:val)'))
endfunction
function! s:count_commits_behind_remote(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let result = s:GitProcess.execute(a:git, [
        \ 'log', '--oneline', '..@{upstream}'
        \])
  if !result.success
    if options.fail_silently
      return 0
    endif
    call s:GitProcess.throw(result)
  endif
  return len(filter(result.content, '!empty(v:val)'))
endfunction

function! s:find_common_ancestor(git, commit1, commit2, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let lhs = empty(a:commit1) ? 'HEAD' : a:commit1
  let rhs = empty(a:commit2) ? 'HEAD' : a:commit2
  let result = s:GitProcess.execute(a:git, [
        \ 'merge-base', lhs, rhs
        \])
  if !result.success
    if options.fail_silently
      return ''
    endif
    call s:GitProcess.throw(result)
  endif
  return substitute(result.output, '\r\?\n$', '', '')
endfunction

" Obsolete
function! s:enclose_if_required(value) abort
  return a:value =~# '\s' ? printf("'%s'", a:value) : a:value
endfunction
function! s:translate(key, options, ...) abort
  let scheme = get(a:000, 0, len(a:key) == 1 ? '-%k%v' : '--%k%{=}v')
  if !has_key(a:options, a:key)
    return []
  endif
  let value = a:options[a:key]
  if s:Prelude.is_list(value)
    return map(value, 's:translate(a:key, { a:key : v:val }, scheme)')
  elseif s:Prelude.is_number(value)
    return value ? [(len(a:key) == 1 ? '-' : '--') . a:key] : []
  else
  return s:StringExt.splitargs(s:StringExt.format(
        \ scheme,
        \ { 'k': 'key', 'v': 'val' },
        \ { 'key': a:key, 'val': s:enclose_if_required(value) },
        \))
  endif
endfunction
function! s:get_available_tags(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let args = s:List.flatten([
        \ 'tag',
        \ s:translate('l', options),
        \ s:translate('list', options),
        \ s:translate('sort', options, '--%k %v'),
        \ s:translate('contains', options, '--%k %v'),
        \ s:translate('points-at', options, '--%k %v'),
        \])
  let result = s:GitProcess.execute(a:git, filter(args, '!empty(v:val)'))
  if !result.success
    if options.fail_silently
      return []
    endif
    call s:GitProcess.throw(result)
  endif
  return result.content
endfunction
function! s:get_available_branches(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let args = s:List.flatten([
        \ 'branch',
        \ s:translate('a', options),
        \ s:translate('all', options),
        \ s:translate('list', options, '--%k %v'),
        \ s:translate('merged', options, '--%k %v'),
        \ s:translate('no-merged', options, '--%k %v'),
        \ '--color=never',
        \])
  let result = s:GitProcess.execute(a:git, filter(args, '!empty(v:val)'))
  if !result.success
    if options.fail_silently
      return []
    endif
    call s:GitProcess.throw(result)
  endif
  return map(result.content, 'matchstr(v:val, "^..\\zs.*$")')
endfunction
function! s:get_available_commits(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let args = s:List.flatten([
        \ 'log',
        \ s:translate('author', options),
        \ s:translate('comitter', options),
        \ s:translate('since', options),
        \ s:translate('after', options),
        \ s:translate('until', options),
        \ s:translate('before', options),
        \ '--pretty=%h',
        \])
  let result = s:GitProcess.execute(a:git, filter(args, '!empty(v:val)'))
  if !result.success
    if options.fail_silently
      return []
    endif
    call s:GitProcess.throw(result)
  endif
  return result.content
endfunction
function! s:get_available_filenames(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let args = s:List.flatten([
        \ 'ls-files',
        \ s:translate('t', options),
        \ s:translate('v', options),
        \ s:translate('c', options),
        \ s:translate('cached', options),
        \ s:translate('d', options),
        \ s:translate('deleted', options),
        \ s:translate('m', options),
        \ s:translate('modified', options),
        \ s:translate('i', options),
        \ s:translate('ignored', options),
        \ s:translate('s', options),
        \ s:translate('staged', options),
        \ s:translate('k', options),
        \ s:translate('killed', options),
        \ s:translate('u', options),
        \ s:translate('unmerged', options),
        \ s:translate('directory', options),
        \ s:translate('empty-directory', options),
        \ s:translate('resolve-undo', options),
        \ s:translate('x', options, '-%k %v'),
        \ s:translate('exclude', options, '--%k %v'),
        \ s:translate('X', options, '-%k %v'),
        \ s:translate('exclude-from', options, '--%k %v'),
        \ s:translate('exclude-per-directory', options, '--%k %v'),
        \ s:translate('exclude-standard', options),
        \ '--full-name',
        \])
  " NOTE:
  " git -C <rep> ls-files returns unix relative paths from the repository
  let result = s:GitProcess.execute(a:git, filter(args, '!empty(v:val)'))
  if !result.success
    if options.fail_silently
      return []
    endif
    call s:GitProcess.throw(result)
  endif
  " return real absolute paths
  let prefix = expand(a:git.worktree) . s:Path.separator()
  let content = map(result.content, 's:Path.realpath(prefix . v:val)')
  return content
endfunction
