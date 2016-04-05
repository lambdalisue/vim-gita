let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita ls-tree',
          \ 'description': 'List the contents of a tree object',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<path>...',
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to ls.',
          \   'If nothing is specified, it ls a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it ls a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it ls a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it ls a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'required': 1,
          \   'complete': function('gita#util#complete#commitish'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#ls_tree#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#ls_tree#default_options),
        \ options
        \)
  call gita#util#option#assign_filenames(options)
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_opener(options)
  call gita#content#ls_tree#open(options)
endfunction

function! gita#command#ls_tree#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#ls_tree', {
      \ 'default_options': {},
      \})
