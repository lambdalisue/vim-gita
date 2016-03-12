let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')

"
" TODO: Refactoring
"

function! s:execute_command(git, pattern, commit, directories, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'cached': 1,
        \ 'no-index': 1,
        \ 'untracked': 1,
        \ 'no-exclude-standard': 1,
        \ 'exclude-standard': 1,
        \ 'text': 1,
        \ 'ignore-case': 1,
        \ 'I': 1,
        \ 'max-depth': 1,
        \ 'word-regexp': 1,
        \ 'invert-match': 1,
        \ 'extended-regexp': 1,
        \ 'basic-regexp': 1,
        \ 'perl-regexp': 1,
        \ 'fixed-strings': 1,
        \ 'all-match': 1,
        \ 'full-name': 1,
        \ 'line-number': 1,
        \})
  let args = ['grep'] + args + [a:commit] + [a:pattern] + ['--'] + a:directories
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction


function! gita#command#grep#call(...) abort
  let options = extend({
        \ 'pattern': '',
        \ 'commit': '',
        \ 'directories': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let commit = gita#variable#get_valid_commit(options.commit, {
        \ '_allow_empty': 1,
        \})
  let content = s:execute_command(
        \ git, options.pattern, commit, options.directories, options
        \)
  let result = {
        \ 'pattern': options.pattern,
        \ 'commit': commit,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita grep',
          \ 'description': 'Print lines matching a pattern',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--cached',
          \ 'search in index instead of in the work tree',
          \)
    call s:parser.add_argument(
          \ '--no-index',
          \ 'find in contents not managed by git',
          \)
    call s:parser.add_argument(
          \ '--untracked',
          \ 'search in both tracked and untracked files',
          \)
    call s:parser.add_argument(
          \ '--exclude-standard',
          \ 'ignore files specified via ".gitignore"',
          \)
    call s:parser.add_argument(
          \ '--invert-match', '-v',
          \ 'show non-matching lines',
          \)
    call s:parser.add_argument(
          \ '--ignore-case', '-i',
          \ 'case insensitive matching',
          \)
    call s:parser.add_argument(
          \ '--word-regexp', '-w',
          \ 'match patterns only at word boundaries',
          \)
    call s:parser.add_argument(
          \ '--text', '-a',
          \ 'process binary files as text',
          \)
    call s:parser.add_argument(
          \ '-I',
          \ 'don''t match patterns in binary files',
          \)
    call s:parser.add_argument(
          \ '--textconv',
          \ 'process binary files with textconv filters',
          \)
    call s:parser.add_argument(
          \ '--max-depth',
          \ 'descend at most DEPTH levels', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--extended-regexp', '-E',
          \ 'use extended POSIX regular expressions',
          \)
    call s:parser.add_argument(
          \ '--basic-regexp', '-G',
          \ 'use basic POSIX regular expressions (default)',
          \)
    call s:parser.add_argument(
          \ '--fixed-strings', '-F',
          \ 'interpret patterns as fixed strings',
          \)
    call s:parser.add_argument(
          \ '--perl-regexp', '-P',
          \ 'use Perl-compatible regular expressions',
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
          \ 'pattern', [
          \   'a match pattern',
          \ ], {
          \})
  endif
  return s:parser
endfunction

function! gita#command#grep#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#grep#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#grep#open(options)
  else
    call gita#command#grep#call(options)
  endif
endfunction

function! gita#command#grep#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#grep', {
      \ 'default_options': {},
      \})

