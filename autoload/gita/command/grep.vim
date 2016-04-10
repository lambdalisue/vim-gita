let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita grep',
          \ 'description': 'Print lines matching patterns',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
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
          \ '--commit',
          \ 'search blobs in the given commit', {
          \   'complete': function('gita#util#complete#commit'),
          \})
    call s:parser.add_argument(
          \ 'patterns', [
          \   'match patterns',
          \ ], {
          \   'type': s:ArgumentParser.types.multiple,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction

function! gita#command#grep#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#grep#default_options),
        \ options
        \)
  call gita#util#option#assign_filenames(options)
  call gita#util#option#assign_opener(options)
  call gita#content#grep#open(options)
endfunction

function! gita#command#grep#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#grep', {
      \ 'default_options': {},
      \})
