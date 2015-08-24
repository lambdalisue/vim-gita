let s:save_cpo = &cpo
set cpo&vim
scriptencoding utf-8

" Vital ======================================================================
let s:_config = {}
let s:_config.executable = 'git'
let s:_config.arguments = ['-c', 'color.ui=false', '--no-pager']

function! s:_vital_loaded(V) dict abort " {{{
  let s:V = a:V
  let s:Prelude = a:V.import('Prelude')
  let s:Process = a:V.import('Process')
  let s:List    = a:V.import('Data.List')
  let s:Path    = a:V.import('System.Filepath')
  let s:INI     = a:V.import('Text.INI')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'Process',
        \ 'Data.List',
        \ 'System.Filepath',
        \ 'Text.INI',
        \]
endfunction " }}}
function! s:_fnamemodify(path, mods) abort " {{{
  let path = a:path !=# '' ? fnamemodify(a:path, a:mods) : ''
  return s:Path.remove_last_separator(path)
endfunction " }}}
function! s:_readfile(path) abort " {{{
  if !filereadable(a:path)
    return []
  endif
  return readfile(a:path)
endfunction " }}}
function! s:_readline(path) abort " {{{
  let contents = s:_readfile(a:path)
  return empty(contents) ? '' : contents[0]
endfunction " }}}

function! s:get_config() abort " {{{
  return s:_config
endfunction " }}}
function! s:set_config(config) abort " {{{
  let s:_config = extend(s:_config, a:config)
endfunction " }}}

" Repository
function! s:find_worktree(path) abort " {{{
  let path = s:_fnamemodify(s:Prelude.path2directory(a:path), ':p')
  let d = s:_fnamemodify(finddir('.git', path . ';'), ':p:h')
  let f = s:_fnamemodify(findfile('.git', path . ';'), ':p')
  " inside '.git' directory is not a working directory
  let d = path =~# printf('\v^%s', d) ? '' : d
  " use deepest dotgit found
  let dotgit = strlen(d) >= strlen(f) ? d : f
  return strlen(dotgit) ? s:_fnamemodify(dotgit, ':h') : ''
endfunction " }}}
function! s:find_repository(worktree) abort " {{{
  let dotgit = s:Path.join([s:_fnamemodify(a:worktree, ':p'), '.git'])
  if isdirectory(dotgit)
    return dotgit
  elseif filereadable(dotgit)
    " in case if the found '.git' is a file which was created via
    " '--separate-git-dir' option
    let lines = readfile(dotgit)
    if !empty(lines)
      let gitdir = matchstr(lines[0], '^gitdir:\s*\zs.\+$')
      let is_abs = s:Path.is_absolute(gitdir)
      return s:_fnamemodify((is_abs ? gitdir : dotgit[:-5] . gitdir), ':p:h')
    endif
  endif
  return ''
endfunction " }}}

function! s:get_relative_path(worktree, path) abort " {{{
  if s:Path.is_relative(a:path)
    throw printf(
          \ 'vital: VCS.Git.Core: "%s" is already a relative path',
          \ a:path,
          \)
  endif
  let prefix = a:worktree . s:Path.separator()
  return substitute(a:path, escape(prefix, '\'), '', '')
endfunction " }}}
function! s:get_absolute_path(worktree, path) abort " {{{
  if s:Path.is_absolute(a:path)
    throw printf(
          \ 'vital: VCS.Git.Core: "%s" is already an absolute path',
          \ a:path,
          \)
  endif
  return s:Path.join([a:worktree, a:path])
endfunction " }}}

" Meta (without using 'git rev-parse'. read '.git/*' directory)
function! s:get_head(repository) abort " {{{
  " The current ref that you’re looking at.
  let filename = s:Path.join(a:repository, 'HEAD')
  return s:_readline(filename)
endfunction " }}}
function! s:get_fetch_head(repository) abort " {{{
  " The SHAs of branch/remote heads that were updated during the last git fetch
  let filename = s:Path.join(a:repository, 'FETCH_HEAD')
  return s:_readfile(filename)
endfunction " }}}
function! s:get_orig_head(repository) abort " {{{
  " When doing a merge, this is the SHA of the branch you’re merging into.
  let filename = s:Path.join(a:repository, 'ORIG_HEAD')
  return s:_readline(filename)
endfunction " }}}
function! s:get_merge_head(repository) abort " {{{
  " When doing a merge, this is the SHA of the branch you’re merging from.
  let filename = s:Path.join(a:repository, 'MERGE_HEAD')
  return s:_readline(filename)
endfunction " }}}
function! s:get_cherry_pick_head(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'CHERRY_PICK_HEAD')
  return s:_readline(filename)
endfunction " }}}
function! s:get_revert_head(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'REVERT_HEAD')
  return s:_readline(filename)
endfunction " }}}
function! s:get_bisect_log(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'BISECT_LOG')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_merge_head(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-merge', 'head-name')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_merge_step(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-merge', 'msgnum')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_merge_total(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-merge', 'end')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_apply_head(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-apply', 'head-name')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_apply_step(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-apply', 'next')
  return s:_readline(filename)
endfunction " }}}
function! s:get_rebase_apply_total(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-apply', 'last')
  return s:_readline(filename)
endfunction " }}}

function! s:is_merging(repository) abort " {{{
  let path = s:Path.join(a:repository, 'MERGE_HEAD')
  return filereadable(path)
endfunction " }}}
function! s:is_cherry_picking(repository) abort " {{{
  let path = s:Path.join(a:repository, 'CHERRY_PICK_HEAD')
  return filereadable(path)
endfunction " }}}
function! s:is_reverting(repository) abort " {{{
  let path = s:Path.join(a:repository, 'REVERT_HEAD')
  return filereadable(path)
endfunction " }}}
function! s:is_bisecting(repository) abort " {{{
  let path = s:Path.join(a:repository, 'BISECT_LOG')
  return filereadable(path)
endfunction " }}}
function! s:is_rebase_merging(repository) abort " {{{
  let path = s:Path.join(a:repository, 'rebase-merge')
  return isdirectory(path)
endfunction " }}}
function! s:is_rebase_merging_interactive(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'rebase-merge', 'interactive')
  return filereadable(filename)
endfunction " }}}
function! s:is_rebase_applying(repository) abort " {{{
  let path = s:Path.join(a:repository, 'rebase-apply')
  return isdirectory(path)
endfunction " }}}
function! s:is_rebase_applying_rebase(repository) abort " {{{
  let path = s:Path.join(a:repository, 'rebase-apply', 'rebasing')
  return filereadable(path)
endfunction " }}}
function! s:is_rebase_applying_am(repository) abort " {{{
  let path = s:Path.join(a:repository, 'rebase-apply', 'applying')
  return filereadable(path)
endfunction " }}}

function! s:get_mode(repository) abort " {{{
  " https://github.com/git/git/blob/dd160d7/contrib/completion/git-prompt.sh#L391-L460
  if s:is_rebase_merging(a:repository)
    let step  = s:get_rebase_merge_step(a:repository)
    let total = s:get_rebase_merge_total(a:repository)
    if s:is_rebase_merging_interactive(a:repository)
      return printf('REBASE-i %d/%d', step, total)
    else
      return printf('REBASE-m %d/%d', step, total)
    endif
  else
    if s:is_rebase_applying(a:repository)
      let step  = s:get_rebase_apply_step(a:repository)
      let total = s:get_rebase_apply_total(a:repository)
      if s:is_rebase_applying_rebase(a:repository)
        return printf('REBASE %d/%d', step, total)
      elseif s:is_rebase_applying_am(a:repository)
        return printf('AM %d/%d', step, total)
      else
        return printf('AM/REBASE %d/%d', step, total)
      endif
    elseif s:is_merging(a:repository)
      return 'MERGING'
    elseif s:is_cherry_picking(a:repository)
      return 'CHERRY-PICKING'
    elseif s:is_reverting(a:repository)
      return 'REVERTING'
    elseif s:is_bisecting(a:repository)
      return 'BISECTING'
    endif
  endif
  return ''
endfunction " }}}
function! s:get_commit_editmsg(repository) abort " {{{
  " This is the last commit’s message. It’s not actually used by Git at all,
  " but it’s there mostly for your reference after you made a commit.
  let filename = s:Path.join(a:repository, 'COMMIT_EDITMSG')
  return s:_readfile(filename)
endfunction " }}}
function! s:get_merge_msg(repository) abort " {{{
  " Enumerates conflicts that happen during your current merge.
  let filename = s:Path.join(a:repository, 'MERGE_MSG')
  return s:_readfile(filename)
endfunction " }}}
function! s:_resolve_ref(repository, ref) abort " {{{
  let filename = s:Path.join(a:repository, a:ref)
  let contents = s:_readline(filename)
  if contents =~# '^ref:\s'
    " recursively resolve ref
    return s:_resolve_ref(
          \ a:repository,
          \ substitute(contents, '^ref:\s', '', ''),
          \)
  elseif !empty(contents)
    return contents
  endif
  " ref is missing in traditional directory, the ref should be written in
  " packed-ref then
  let filename = s:Path.join(a:repository, 'packed-refs')
  let filter_code = printf(
        \ 'v:val[0] != "#" && v:val[-%d:] ==# a:ref',
        \ len(a:ref)
        \)
  let packed_refs = filter(s:_readfile(filename), filter_code)
  return get(split(get(packed_refs, 0, '')), 0, '')
endfunction " }}}
function! s:get_local_hash(repository, branch) abort " {{{
  if a:branch =~# 'HEAD'
    let HEAD = s:get_head(a:repository)
    let ref = s:Path.join(
          \ a:repository,
          \ substitute(HEAD, '^ref:\s', '', ''),
          \)
  else
    let ref = s:Path.join('refs', 'heads', a:branch)
  endif
  return s:_resolve_ref(a:repository, ref)
endfunction " }}}
function! s:get_remote_hash(repository, remote, branch) abort " {{{
  let ref = s:Path.join('refs', 'remotes', a:remote, a:branch)
  return s:_resolve_ref(a:repository, ref)
endfunction " }}}

" Config (without using 'git config'. read '.git/config' directly)
function! s:get_repository_config(repository) abort " {{{
  let filename = s:Path.join(a:repository, 'config')
  if !filereadable(filename)
    return {}
  endif
  return s:INI.parse_file(filename)
endfunction " }}}
function! s:get_branch_remote(config, local_branch) abort " {{{
  " a name of remote which the {local_branch} connect
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  return get(section, 'remote', '')
endfunction " }}}
function! s:get_branch_merge(config, local_branch, ...) abort " {{{
  " a branch name of remote which {local_branch} connect
  let truncate = get(a:000, 0, 0)
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  let merge = get(section, 'merge', '')
  return truncate ? substitute(merge, '\v^refs/heads/', '', '') : merge
endfunction " }}}
function! s:get_remote_fetch(config, remote) abort " {{{
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'fetch', '')
endfunction " }}}
function! s:get_remote_url(config, remote) abort " {{{
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'url', '')
endfunction " }}}
function! s:get_comment_char(config, ...) abort " {{{
  let default = get(a:000, 0, '#')
  let section = get(a:config, 'core', {})
  if empty(section)
    return default
  endif
  return get(section, 'commentchar', default)
endfunction " }}}

" Execution
function! s:system(args, ...) abort " {{{
  let args = s:List.flatten(a:args)
  let opts = extend({
        \ 'stdin': '',
        \ 'timeout': 0,
        \}, get(a:000, 0, {}))
  let original_opts = deepcopy(opts)
  " prevent E677
  if strlen(opts.stdin)
    let opts.input = opts.stdin
    unlet opts.stdin
  endif
  let stdout = s:Process.system(args, opts)
  " remove trailing newline
  let stdout = substitute(stdout, '\v%(\r?\n)$', '', '')
  let status = s:Process.get_last_status()
  return { 'stdout': stdout, 'status': status, 'args': args, 'opts': original_opts }
endfunction " }}}
function! s:system_interactive(args, ...) abort " {{{
  let args = s:List.flatten(a:args)
  let opts = get(a:000, 0, {})
  let saved_shell = &shell
  let saved_shellcmdflag = &shellcmdflag
  set shell&
  set shellcmdflag& shellcmdflag+=il
  try
    redir => stdout
    execute printf('!%s', join(args, ' '))
    redir END
  finally
    let &shell = saved_shell
    let &shellcmdflag = saved_shellcmdflag
  endtry
  let stdout_lines = split(stdout, '\v%(\r?\n)')
  let stdout_lines = stdout_lines[1:-1]
  if get(stdout_lines, -1, '') =~# '^shell returned'
    let status = matchstr(stdout_lines[-1], '\v^shell returned \zs\d\ze') + 0
    let stdout_lines = stdout_lines[0:-3]
  else
    let status = 0
  endif
  let stdout = join(stdout_lines, "\n")
  return { 'stdout': stdout, 'status': status, 'args': args, 'opts': opts }
endfunction " }}}
function! s:exec(args, ...) abort " {{{
  let args = [s:_config.executable, s:_config.arguments, a:args]
  let opts = get(a:000, 0, {})
  if get(opts, 'interactive', 0)
    return s:system_interactive(args, opts)
  else
    return s:system(args, opts)
  endif
endfunction " }}}

" Version
function! s:get_version() abort " {{{
  let result = s:exec(['--version'])
  if result.status
    return '0.0.0'
  endif
  return matchstr(result.stdout, '^git version \zs.*$')
endfunction " }}}

let &cpo = s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
