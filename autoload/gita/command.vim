let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Console = s:V.import('Vim.Console')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:complete_action(arglead, cmdline, cursorpos, ...) abort
  let candidates = filter([
      \ 'add',
      \ 'apply',
      \ 'blame',
      \ 'branch',
      \ 'browse',
      \ 'cd',
      \ 'chaperone',
      \ 'checkout',
      \ 'commit',
      \ 'diff',
      \ 'diff-ls',
      \ 'grep',
      \ 'lcd',
      \ 'ls-files',
      \ 'ls-tree',
      \ 'merge',
      \ 'patch',
      \ 'rebase',
      \ 'reset',
      \ 'rm',
      \ 'show',
      \ 'status',
      \ 'init',
      \ 'pull',
      \ 'push',
      \ 'stash',
      \ 'remote',
      \ 'tag',
      \ 'log',
      \], 'v:val =~# ''^'' . a:arglead')
  return candidates
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita[!]',
          \ 'description': [
          \   'A git manipulation command. It executes a specified gita''s command or a specified git command if action is not found.',
          \   'Additionally, if the command called with a bang (!), it execute a git command instead of gita''s command.',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'A name of a gita action (followings). If a non gita action is specified, git command will be called directly.',
          \   '',
          \   'add       : Add file contents to the index',
          \   'blame     : Show what revision and author last modified each line of a file',
          \   'branch    : List, create, or delete branches',
          \   'browse    : Browse a URL of the remote content',
          \   'cd        : Change a current directory to the working tree top',
          \   'chaperone : Compare differences and help to solve conflictions',
          \   'checkout  : Switch branches or restore working tree files',
          \   'commit    : Record changes to the repository',
          \   'diff      : Show changes between commits, commit and working tree, etc',
          \   'diff-ls   : Show a list of changed files between commits',
          \   'grep      : Print lines matching patterns',
          \   'ls-files  : Show information about files in the index and the working tree',
          \   'lcd       : Change a current directory to the working tree top (lcd)',
          \   'ls-tree   : List the contents of a tree object',
          \   'merge     : Join two or more development histories together',
          \   'patch     : Partially add/reset changes to/from index',
          \   'rebase    : Forward-port local commits to the update upstream head',
          \   'reset     : Reset current HEAD to the specified state',
          \   'rm        : Remove files from the working tree and from the index',
          \   'show      : Show a content of a commit or a file',
          \   'status    : Show and manipulate s status of the repository',
          \   '',
          \   'Note that each sub-commands also have -h/--help option',
          \ ], {
          \   'required': 1,
          \   'terminal': 1,
          \   'complete': function('s:complete_action'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if !empty(options)
    let args  = join(options.__unknown__)
    let name  = get(options, 'action', '')
    let git = gita#core#get()
    try
      if a:bang ==# '!'
        call gita#process#shell(git, map(
              \ gita#process#splitargs(a:args),
              \ 'gita#meta#expand(v:val)'
              \))
      else
        try
          let funcname = printf(
                \ 'gita#command#%s#command',
                \ substitute(name, '-', '_', 'g'),
                \)
          call call(funcname, [a:bang, a:range, args])
        catch /^Vim\%((\a\+)\)\=:E117/
          " fail silently and execute git command
          call gita#process#execute(git, map(
                \ gita#process#splitargs(a:args),
                \ 'gita#meta#expand(v:val)',
                \))
          call gita#trigger_modified()
        endtry
      endif
    catch /^\%(vital: Git[:.]\|gita:\)/
      call gita#util#handle_exception()
    endtry
  endif
endfunction

function! gita#command#complete(arglead, cmdline, cursorpos) abort
  let bang    = a:cmdline =~# '^[^ ]\+!' ? '!' : ''
  let cmdline = substitute(a:cmdline, '^[^ ]\+!\?\s', '', '')
  let cmdline = substitute(cmdline, '[^ ]\+$', '', '')

  let parser  = s:get_parser()
  let options = parser.parse(bang, [0, 0], cmdline)
  if !empty(options)
    let name = get(options, 'action', '')
    try
      if bang !=# '!'
        try
          let funcname = printf(
                \ 'gita#command#%s#complete',
                \ substitute(name, '-', '_', 'g'),
                \)
          return call(funcname, [a:arglead, cmdline, a:cursorpos])
        catch /^Vim\%((\a\+)\)\=:E117/
          " fail silently
        endtry
      endif
      " complete filename
      return gita#util#complete#filename(a:arglead, cmdline, a:cursorpos)
    catch /^\%(vital: Git[:.]\|gita:\)/
      " fail silently
      call s:Console.debug(v:exception)
      call s:Console.debug(v:throwpoint)
      return []
    endtry
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
