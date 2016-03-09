let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcessOld = s:V.import('Git.ProcessOld')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'd',
        \ 'r',
        \ 't',
        \ 'long',
        \ 'name-only', 'name-status',
        \ 'abbrev',
        \ 'full-name',
        \ 'full-tree',
        \])
  return options
endfunction

function! s:apply_command(git, commit, pathlist, options) abort
  let options = s:pick_available_options(a:options)
  let options['commit'] = a:commit
  if !empty(a:pathlist)
    let options['--'] = a:pathlist
  endif
  let result = gita#execute(a:git, 'ls-tree', options)
  if result.status
    call s:GitProcessOld.throw(result)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction


function! gita#command#ls_tree#call(...) abort
  let options = extend({
        \ 'commit': '',
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit)
  if commit =~# '^.\{-}\.\.\..\{-}$'
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let _commit = s:GitInfo.find_common_ancestor(git, lhs, rhs)
    let content = s:apply_command(git, _commit, [], options)
  elseif commit =~# '^.\{-}\.\..\{-}$'
    let _commit  = s:GitTerm.split_range(commit)[0]
    let content = s:apply_command(git, _commit, [], options)
  else
    let content = s:apply_command(git, commit, [], options)
  endif
  let result = {
        \ 'commit': commit,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita ls-tree',
          \ 'description': 'List the contents of a tree object',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<path>...',
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '-d',
          \ 'show only the named tree entry itself, not its children',
          \)
    call s:parser.add_argument(
          \ '-r',
          \ 'recurse into sub-trees',
          \)
    call s:parser.add_argument(
          \ '-t',
          \ 'show tree entries even when going to recurse them',
          \)
    call s:parser.add_argument(
          \ '--long', '-l',
          \ 'show object size of blob (file) entries',
          \)
    call s:parser.add_argument(
          \ '--name-only',
          \ 'list only filenames instead of the "long" output, one per line',
          \)
    call s:parser.add_argument(
          \ '--name-status',
          \ 'list only filenames instead of the "long" output, one per line',
          \)
    call s:parser.add_argument(
          \ '--abbrev', [
          \   'instead of showing the full 40-byte hexadecimal object lines',
          \   'show only a partial prefix.',
          \ ], {
          \   'pattern': '^\d\+$',
          \   'conflicts': ['ui'],
          \})
    call s:parser.add_argument(
          \ '--full-name',
          \ 'show the full path names',
          \)
    call s:parser.add_argument(
          \ '--full-tree',
          \ 'do not limit the listing to the current working directory',
          \)
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
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to ls.',
          \   'If nothing is specified, it ls a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it ls a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it ls a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it ls a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#ls_tree#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#ls_tree#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#ls_tree#open(options)
  else
    call gita#command#ls_tree#call(options)
  endif
endfunction

function! gita#command#ls_tree#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#ls_tree', {
      \ 'default_options': {},
      \})
