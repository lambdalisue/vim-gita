let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita ls-files',
          \ 'description': 'Show information about files in the index and the working tree',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \ 'unknown_description': '<file>...',
          \})
    call s:parser.add_argument(
          \ '--cached', '-c',
          \ 'show cached files',
          \)
    call s:parser.add_argument(
          \ '--deleted', '-d',
          \ 'show deleted files',
          \)
    call s:parser.add_argument(
          \ '--modified', '-m',
          \ 'show modified files',
          \)
    call s:parser.add_argument(
          \ '--others',
          \ 'show other (i.e. untracked) files',
          \)
    call s:parser.add_argument(
          \ '--ignored', '-i',
          \ 'show only ignored files',
          \)
    call s:parser.add_argument(
          \ '--stage', '-s',
          \ 'show staged contents'' object name, made bits and stage number',
          \)
    call s:parser.add_argument(
          \ '--unstage', '-u',
          \ 'show unstaged files (forces --stage)',
          \)
    call s:parser.add_argument(
          \ '--killed', '-k',
          \ 'show files on the filesystem that need to be removed due to file/directory conflicts',
          \)
    call s:parser.add_argument(
          \ '--directory',
          \ 'if a whole directory is classified as "other", show just its name',
          \)
    call s:parser.add_argument(
          \ '--no-empty-directory',
          \ 'do not list empty directories',
          \)
    call s:parser.add_argument(
          \ '--exclude', '-x',
          \ 'skip untracked files matching pattern', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--exclude-from', '-X',
          \ 'read exclude patterns from file; 1 per line', {
          \   'complete': function('gita#util#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--exclude-per-directory',
          \ 'read additional exclude patterns that apply only to the directory and its subdirectories', {
          \   'complete': function('gita#util#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--exclude-standard',
          \ 'add the standard Git exclusion',
          \)
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction

function! gita#command#ls_files#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#ls_files#default_options),
        \ options
        \)
  call gita#util#option#assign_filenames(options)
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_opener(options)
  call gita#content#ls_files#open(options)
endfunction

function! gita#command#ls_files#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#ls_files', {
      \ 'default_options': {},
      \})
