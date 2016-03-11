let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita diff-ls',
          \ 'description': 'Show a diff content of a commit or files (UI only)',
          \ 'complete_threshold': g:gita#complete_threshold,
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
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to diff.',
          \   'If nothing is specified, it diff a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it diff a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it diff a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it diff a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#complete#commit'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#diff_ls#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#diff_ls#default_options),
        \ options,
        \)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options)
  call gita#command#ui#diff_ls#open(options)
endfunction

function! gita#command#diff_ls#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#diff_ls', {
      \ 'default_options': {},
      \})
