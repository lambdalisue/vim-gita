let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'delete',
        \ 'D',
        \ 'create-reflog',
        \ 'force',
        \ 'move',
        \ 'M',
        \ 'remotes',
        \ 'all',
        \ 'list',
        \ 'track', 'no-track',
        \ 'set-upstream', 'set-upstream-to', 'unset-upstream',
        \ 'contains',
        \ 'merged', 'no-merged',
        \ 'branchname',
        \ 'start-point',
        \ 'oldbranch',
        \ 'newbranch',
        \])
  return options
endfunction

function! s:get_branch_content(git, options) abort
  let options = s:pick_available_options(a:options)
  let options['verbose'] = 1
  let result = gita#execute(a:git, 'branch', options)
  if result.status
    call s:GitProcess.throw(result)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#branch#call(...) abort
  let options = extend({
        \ 'all': 0,
        \ 'remotes': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let content = s:get_branch_content(git, options)
  if options.remotes
    let content = map(
          \ content,
          \ 'substitute(v:val, "^\\(..\\)", "\\1remotes/", "")'
          \)
  endif
  let result = {
        \ 'content': content,
        \ 'options': options,
        \}
  return result
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
          \ 'set up tracking mode (see git-pull(1))',
          \)
    call s:parser.add_argument(
          \ '--set-upstream-to', '-u',
          \ 'change the upstram info', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--unset-upstraem',
          \ 'unset the upstream info',
          \)
    call s:parser.add_argument(
          \ '--remotes', '-r',
          \ 'act on remote-tracking branches',
          \)
    call s:parser.add_argument(
          \ '--contains',
          \ 'print only branches that contains the commit', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'list both remote-tracking and local branches',
          \)
    call s:parser.add_argument(
          \ '--delete', '-d',
          \ 'delete fully merged branch',
          \)
    call s:parser.add_argument(
          \ '-D',
          \ 'delete branch (even if not merged)',
          \)
    call s:parser.add_argument(
          \ '--move', '-m',
          \ 'move/rename a branch and its reflog',
          \)
    call s:parser.add_argument(
          \ '-M',
          \ 'move/rename a branch, even if target exists',
          \)
    call s:parser.add_argument(
          \ '--list',
          \ 'list branch names',
          \)
    call s:parser.add_argument(
          \ '--create-reflog', '-l',
          \ 'create the branch''s reflog',
          \)
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'force creation, mov/rename, deletion',
          \)
    call s:parser.add_argument(
          \ '--no-merged',
          \ 'print only not merged branches', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--merged',
          \ 'print only merged branches', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--ui',
          \ 'show a buffer instead of echo the result. imply --quiet', {
          \   'default': 1,
          \   'deniable': 1,
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
  endif
  return s:parser
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
    call gita#command#ui#branch#open(options)
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
