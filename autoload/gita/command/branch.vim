let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita branch',
          \ 'description': 'List, create, or delete branches',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--track', '-t',
          \ 'set up tracking mode (see git-pull(1))', {
          \   'conflicts': [
          \     'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--no-track',
          \ 'do not set up "upstream" configuration', {
          \   'conflicts': [
          \     'track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--set-upstream-to', '-u',
          \ 'change the upstram info', {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': [
          \     'track', 'no-track', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--unset-upstraem',
          \ 'unset the upstream info', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to',
          \     'move', 'M', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--remotes', '-r',
          \ 'act on remote-tracking branches',
          \)
    call s:parser.add_argument(
          \ '--contains',
          \ 'print only branches that contains the commit', {
          \   'on_default': 'HEAD',
          \   'complete': function('gita#util#complete#commit'),
          \})
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'list both remote-tracking and local branches',
          \)
    call s:parser.add_argument(
          \ '--delete', '-d',
          \ 'delete fully merged branch', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '-D',
          \ 'delete branch (even if not merged)', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--move', '-m',
          \ 'move/rename a branch and its reflog', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'M', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '-M',
          \ 'move/rename a branch, even if target exists', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'delete', 'D',
          \     'list',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--list',
          \ 'list branch names. the value is used to filter branches', {
          \   'type': s:ArgumentParser.types.any,
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--create-reflog', '-l',
          \ 'create the branch''s reflog', {
          \   'superordinates': ['track', 'set-upstream', 'no-track'],
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'force creation, move/rename, deletion', {
          \   'conflicts': ['list'],
          \})
    call s:parser.add_argument(
          \ '--no-merged',
          \ 'print only not merged branches', {
          \   'on_default': 'HEAD',
          \   'complete': function('gita#util#complete#commit'),
          \})
    call s:parser.add_argument(
          \ '--merged',
          \ 'print only merged branches', {
          \   'on_default': 'HEAD',
          \   'complete': function('gita#util#complete#commit'),
          \})
    call s:parser.add_argument(
          \ 'branch',
          \ 'the name of the branch to create', {
          \   'complete': function('gita#util#complete#branch'),
          \   'conflicts': ['list'],
          \})
    call s:parser.add_argument(
          \ 'newbranch',
          \ 'the new name for an existing branch', {
          \   'complete': function('gita#util#complete#local_branch'),
          \   'superordinates': ['move', 'M'],
          \})
    call s:parser.add_argument(
          \ 'start-point',
          \ 'the new branch head will point to this commit', {
          \   'complete': function('gita#util#complete#commitish'),
          \   'superordinates': [
          \     'set-upstream', 'track', 'no-track',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \   'superordinates': ['list'],
          \})
    function! s:parser.hooks.pre_validate(options) abort
      if empty(s:parser.get_conflicted_arguments('list', a:options))
        let a:options.list = get(a:options, 'list', 1)
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'track': 1,
        \ 'no-track': 1,
        \ 'set-upstream-to': 1,
        \ 'unset-upstream': 1,
        \ 'remotes': 1,
        \ 'contains': '--%k %v',
        \ 'all': 1,
        \ 'delete': 1,
        \ 'D': 1,
        \ 'move': 1,
        \ 'M': 1,
        \ 'list': '--%k %v',
        \ 'create-reflog': 1,
        \ 'force': 1,
        \ 'no-merged': '--%k %v',
        \ 'merged': '--%k %v',
        \})
  let args = [
        \ 'branch',
        \ '--no-column',
        \ '--no-color',
        \ '--no-abbrev',
        \ '--verbose',
        \] + args + [
        \ get(a:options, 'branch', ''),
        \ get(a:options, 'newbranch', ''),
        \ gita#normalize#commit(a:git, get(a:options, 'start-point', '')),
        \]
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#branch#command(bang, range, args) abort
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#branch#default_options),
        \ options
        \)
  if empty(get(options, 'list'))
    let git = gita#core#get_or_fail()
    let args = s:args_from_options(git, options)
    call gita#process#execute(git, args)
    call gita#trigger_modified()
  else
    call gita#util#option#assign_opener(options)
    call gita#content#branch#open(options)
  endif
endfunction

function! gita#command#branch#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#branch', {
      \ 'default_options': {},
      \})
