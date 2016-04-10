let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita diff-ls',
          \ 'description': 'Show a list of changed files between commits',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--ignore-submodules', [
          \   'ignore changes to submodules in the diff generation',
          \   '- none       consider the submodule modified when it either contains untracked or modified files or its HEAD differs',
          \   '- untracked  submodules are not considered dirty when they only contain untracked content',
          \   '- dirty      ignores all changes to the work tree of submodules',
          \   '- all        hides all changes to submodules',
          \ ], {
          \   'on_default': 'all',
          \   'choices': ['none', 'untracked', 'dirty', 'all'],
          \ }
          \)
    call s:parser.add_argument(
          \ '--no-renames',
          \ 'turn off rename detection',
          \)
    call s:parser.add_argument(
          \ '-B',
          \ 'break complete rewrite changes into pairs of delete and create.', {
          \   'pattern': '^\d\+\(/\d\+\)\?$',
          \})
    call s:parser.add_argument(
          \ '--find-renames', '-M',
          \ 'detect renames. if <n> is specified, it is a threshold on the similarity index', {
          \   'on_default': '50%',
          \   'pattern': '^\d\+%\?$',
          \})
    call s:parser.add_argument(
          \ '--find-copies', '-C',
          \ 'detect copies as well as renames. it has the same meaning as for -M<n>', {
          \   'on_default': '50%',
          \   'pattern': '^\d\+%\?$',
          \})
    call s:parser.add_argument(
          \ '--find-copies-harder',
          \ 'try harder to find copies. this is a very expensive operation for large projects',
          \)
    call s:parser.add_argument(
          \ '--text', '-a',
          \ 'treat all files as text',
          \)
    call s:parser.add_argument(
          \ '--ignore-space-change', '-b',
          \ 'ignore changes in amount of whitespace',
          \)
    call s:parser.add_argument(
          \ '--ignore-all-space', '-w',
          \ 'ignore whitespace when comparing lines',
          \)
    call s:parser.add_argument(
          \ '--ignore-blank-lines',
          \ 'ignore changes whose lines are all blank',
          \)
    call s:parser.add_argument(
          \ '--cached',
          \ 'compare with a content in the index',
          \)
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to diff.',
          \   'If nothing is specified, it diff a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it diff a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it diff a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it diff a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#util#complete#commitish'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#diff_ls#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#diff_ls#default_options),
        \ options
        \)
  call gita#util#option#assign_opener(options)
  call gita#content#diff_ls#open(options)
endfunction

function! gita#command#diff_ls#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#diff_ls', {
      \ 'default_options': {},
      \})
