let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'delete': 1,
        \ 'D': 1,
        \ 'create-reflog': 1,
        \ 'force': 1,
        \ 'move': 1,
        \ 'M': 1,
        \ 'remotes': 1,
        \ 'all': 1,
        \ 'list': '--%k %v',
        \ 'track': 1,
        \ 'no-track': 1,
        \ 'set-upstream': 1,
        \ 'set-upstream-to': 1,
        \ 'unset-upstream': 1,
        \ 'contains': '--%k %v',
        \ 'merged': '--%k %v',
        \ 'no-merged': '--%k %v',
        \})
  if has_key(a:options, 'branch')
    let args += [a:options.branch]
  endif
  if has_key(a:options, 'start-point') && gita#util#any(a:options, [
        \ 'set-upstream', 'track', 'no-track',
        \])
    let args += [a:options['start-point']]
  endif
  if has_key(a:options, 'newbranch') && gita#util#any(a:options, [
        \ 'move', 'M',
        \])
    let args += [get(a:options, 'newbranch', '')]
  endif
  let args = ['branch', '--no-color', '--verbose'] + args
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita branch',
          \ 'description': 'List, create, or delete branches',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--track', '-t',
          \ 'set up tracking mode (see git-pull(1))', {
          \   'conflicts': [
          \     'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--no-track',
          \ 'do not set up "upstream" configuration', {
          \   'conflicts': [
          \     'track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--set-upstream-to', '-u',
          \ 'change the upstram info', {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': [
          \     'track', 'no-track', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--unset-upstraem',
          \ 'unset the upstream info', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to',
          \     'move', 'M', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--remotes', '-r',
          \ 'act on remote-tracking branches',
          \)
    call s:parser.add_argument(
          \ '--contains',
          \ 'print only branches that contains the commit', {
          \   'complete': function('gita#complete#commit'),
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
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '-D',
          \ 'delete branch (even if not merged)', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--move', '-m',
          \ 'move/rename a branch and its reflog', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'M', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '-M',
          \ 'move/rename a branch, even if target exists', {
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'delete', 'D',
          \     'list', 'ui',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--list',
          \ 'list branch names. the value is used to filter branches. imply --ui', {
          \   'type': s:ArgumentParser.types.value,
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
          \ 'force creation, mov/rename, deletion',
          \)
    call s:parser.add_argument(
          \ '--no-merged',
          \ 'print only not merged branches', {
          \   'complete': function('gita#complete#commit'),
          \})
    call s:parser.add_argument(
          \ '--merged',
          \ 'print only merged branches', {
          \   'complete': function('gita#complete#commit'),
          \})
    call s:parser.add_argument(
          \ 'branch',
          \ 'the name of the branch to create', {
          \   'complete': function('gita#complete#branch'),
          \   'conflicts': ['ui'],
          \})
    call s:parser.add_argument(
          \ 'newbranch',
          \ 'the new name for an existing branch', {
          \   'complete': function('gita#complete#local_branch'),
          \   'superordinates': ['move', 'M'],
          \})
    call s:parser.add_argument(
          \ 'start-point',
          \ 'the new branch head will point to this commit', {
          \   'complete': function('gita#complete#commit'),
          \   'superordinates': [
          \     'set-upstream', 'track', 'no-track',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--ui',
          \ 'show a buffer instead of echo the result. imply --quiet', {
          \   'deniable': 1,
          \   'conflicts': [
          \     'track', 'no-track', 'set-upstream-to', 'unset-upstream',
          \     'move', 'M', 'delete', 'D',
          \     'branch',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \   'superordinates': ['ui'],
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'a line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \   'superordinates': ['ui'],
          \})
    function! s:parser.hooks.pre_validate(options) abort
      if empty(s:parser.get_conflicted_arguments('ui', a:options))
        let a:options.ui = 1
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction


function! gita#command#branch#call(...) abort
  let options = extend({
        \ 'remotes': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  if gita#util#any(options, ['set-upstream', 'track', 'no-track'])
    let options.branch = gita#variable#get_valid_commit(git, 
          \ options.branch,
          \)
    let options['start-point'] = gita#variable#get_valid_commit(git, 
          \ get(options, 'start-point', ''),
          \ { '_allow_empty': 1 },
          \)
  elseif gita#util#any(options, ['set-upstream-to', 'unset-upstream'])
    let options.branch = gita#variable#get_valid_commit(git, 
          \ get(options, 'branch', ''),
          \ { '_allow_empty': 1 },
          \)
  elseif gita#util#any(options, ['move', 'M'])
    let options.branch = gita#variable#get_valid_commit(git, 
          \ get(options, 'branch', ''),
          \)
    let options.newbranch = gita#variable#get_valid_commit(git, 
          \ get(options, 'newbranch', ''),
          \)
  elseif gita#util#any(options, ['delete', 'D'])
    let options.branch = gita#variable#get_valid_commit(git, 
          \ get(options, 'branch', ''),
          \)
  endif
  let content = s:execute_command(git, options)
  if options.remotes
    let content = map(
          \ content,
          \ 'substitute(v:val, ''^\(..\)'', ''\1remotes/'', '''')'
          \)
  endif
  if gita#util#any(options, [
        \ 'set-upstream', 'track', 'no-track',
        \ 'set-upstream-to', 'unset-upstream',
        \ 'move', 'M', 'delete', 'D',
        \ 'branch',
        \])
    call gita#util#doautocmd('User', 'GitaStatusModified')
  endif
  let result = {
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! gita#command#branch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#branch#default_options),
        \ options,
        \)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#ui#branch#open(options)
  else
    call gita#command#branch#call(options)
  endif
endfunction

function! gita#command#branch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#branch', {
      \ 'default_options': {},
      \})
