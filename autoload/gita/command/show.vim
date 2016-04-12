let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<path>',
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--worktree', '-w',
          \ 'open a content of a file in working tree', {
          \   'conflicts': ['ancestor', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ancestors', '-1',
          \ 'open a content of a file in a common ancestor during merge', {
          \   'conflicts': ['worktree', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ours', '-2',
          \ 'open a content of a file in our side during merge', {
          \   'conflicts': ['worktree', 'ancestors', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--theirs', '-3',
          \ 'open a content of a file in thier side during merge', {
          \   'conflicts': ['worktree', 'ancestors', 'ours'],
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'a line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    if g:gita#develop
      call s:parser.add_argument(
            \ '--patch',
            \ 'show a content of a file in PATCH mode. It force to open an INDEX file content (ONLY IN DEVELOPMENT MODE)',
            \)
    endif
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit which you want to see.',
          \   'if nothing is specified, it show a content of the index.',
          \   'if <commit> is specified, it show a content of the named <commit>.',
          \   'if <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'if <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('gita#util#complete#commitish'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#show#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#show#default_options),
        \ options
        \)
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_selection(options)
  call gita#util#option#assign_opener(options)
  if !empty(options.__unknown__)
    let options.filename = options.__unknown__[0]
  endif
  call gita#content#show#open(options)
endfunction

function! gita#command#show#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#show', {
      \ 'default_options': {},
      \})
