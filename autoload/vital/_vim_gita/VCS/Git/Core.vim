"******************************************************************************
" Core functions of Git manipulation.
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital ======================================================================
let s:_config = {}
let s:_config.executable = 'git'
let s:_config.arguments = ['-c', 'color.ui=false']

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
  if !s:Path.is_absolute(a:path)
    return a:path
  endif
  let prefix = a:worktree . s:Path.separator()
  return substitute(a:path, prefix, '', '')
endfunction " }}}
function! s:get_absolute_path(worktree, path) abort " {{{
  if !s:Path.is_relative(a:path)
    return a:path
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
function! s:get_merge_mode(repository) abort " {{{
  " Used to communicate constraints that were originally given to git merge to
  " git commit when a merge conflicts, and a separate git commit is needed to
  " conclude it. Currently --no-ff is the only constraints passed this way.
  let filename = s:Path.join(a:repository, 'MERGE_MODE')
  return s:_readline(filename)
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
function! s:get_local_hash(repository, branch) abort " {{{
  let filename = s:Path.join(a:repository, 'refs', 'heads', a:branch)
  return s:_readline(filename)
endfunction " }}}
function! s:get_remote_hash(repository, remote, branch) abort " {{{
  let target = s:Path.join('refs', 'remotes', a:remote, a:branch)
  let filename = s:Path.join(a:repository, target)
  let hash = s:_readline(filename)
  if empty(hash)
    " sometime the file is missing
    let filename = s:Path.join(a:repository, 'packed-refs')
    let packed_refs = filter(s:_readfile(filename),
                      \      'v:val[0] != "#" && v:val[-'.len(target).':] == target')
    return get(split(get(packed_refs, 0, '')), 0, '')
  endif
  return hash
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
  let saved_cwd = getcwd()
  let args = s:List.flatten(a:args)
  let opts = extend({
        \ 'stdin': '',
        \ 'timeout': 0,
        \ 'cwd': saved_cwd,
        \}, get(a:000, 0, {}))
  let original_opts = deepcopy(opts)
  " prevent E677
  if strlen(opts.stdin)
    let opts.input = opts.stdin
  endif
  try
    let cwd = s:Prelude.path2directory(opts.cwd)
    silent execute 'lcd' fnameescape(cwd)
    let stdout = s:Process.system(args, opts)
  finally
    silent execute 'lcd' fnameescape(saved_cwd)
  endtry
  " remove trailing newline
  let stdout = substitute(stdout, '\v%(\r?\n)$', '', '')
  let status = s:Process.get_last_status()
  return { 'stdout': stdout, 'status': status, 'args': args, 'opts': original_opts }
endfunction " }}}
function! s:exec(args, ...) abort " {{{
  let args = [s:_config.executable, s:_config.arguments, a:args]
  let opts = get(a:000, 0, {})
  return s:system(args, opts)
endfunction " }}}

function! s:args(args, ...) abort " {{{
  let opts = get(a:000, 0, {})
  let args = ['git', '-c', 'color.ui=false']
  if has_key(opts, 'git_dir')
    call add(args, '--git-dir')
    call add(args, fnameescape(fnamemodify(opts.git_dir, ':p')))
  endif
  if has_key(opts, 'work_tree')
    call add(args, '--work-tree')
    call add(args, fnameescape(fnamemodify(opts.work_tree, ':p')))
  endif
  if has_key(opts, 'C')
    call add(args, '--C')
    call add(args, fnameescape(fnamemodify(opts.C, ':p')))
  endif
  return extend(args, a:args)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

