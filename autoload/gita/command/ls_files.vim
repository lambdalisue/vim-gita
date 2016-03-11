let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, filenames, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'cached': 1,
        \ 'deleted': 1,
        \ 'modified': 1,
        \ 'others': 1,
        \ 'ignored': 1,
        \ 'stage': 1,
        \ 'directory': 1,
        \ 'no-empty-directory': 1,
        \ 'unmerged': 1,
        \ 'killed': 1,
        \ 'exclude-standard': 1,
        \ 'error-unmatch': 1,
        \ 'full-name': 1,
        \ 'abbrev': 1,
        \ 'exclude': '--%k %v',
        \ 'exclude-from': '--%k %v',
        \ 'exclude-per-directory': '--%k %v',
        \ 'with-tree': '--%k %v',
        \})
  let args = ['ls-files'] + args + ['--'] + a:filenames
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction


function! gita#command#ls_files#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(v:val)',
        \)
  let content = s:execute_command(git, filenames, options)
  let result = {
        \ 'content': content,
        \ 'options': options,
        \ 'filenames': filenames,
        \}
  return result
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita ls-files',
          \ 'description': 'Show information about files in the index and the working tree',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'complete_unknown': function('gita#complete#filename'),
          \ 'unknown_description': '<file>...',
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
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
          \   'complete': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--exclude-per-directory',
          \ 'read additional exclude patterns that apply only to the directory and its subdirectories', {
          \   'complete': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--exclude-standard',
          \ 'add the standard Git exclusion',
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

function! gita#command#ls_files#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  let options.filenames = options.__unknown__
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#ls_files#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#ls_files#open(options)
  else
    call gita#command#ls_files#call(options)
  endif
endfunction

function! gita#command#ls_files#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#ls_files', {
      \ 'default_options': {},
      \})
