let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcessOld = s:V.import('Git.ProcessOld')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  return s:Dict.pick(a:options, [
        \ 'stat', 'numstat', 'summary', 'check',
        \ 'index', 'cached',
        \ 'build-fake-ancestor',
        \ 'reverse',
        \ 'reject',
        \ 'p',
        \ 'C',
        \ 'unidiff-zero',
        \ 'apply',
        \ 'no-add',
        \ 'exclude', 'include',
        \ 'ignore-space-change', 'ignore-whitespace',
        \ 'whitespace',
        \ 'inaccurate-eof',
        \ 'recount',
        \ 'directory',
        \ 'unsafe-paths',
        \ 'allow-overlap',
        \])
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['--'] = a:filenames
  let options['verbose'] = 1
  let result = gita#execute_old(a:git, 'apply', options)
  if result.status
    call s:GitProcessOld.throw(result)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#apply#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  if empty(options.filenames)
    call gita#throw('ValidationError: "filenames" cannot be empty')
  endif
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(v:val)',
        \)
  let content = s:apply_command(git, filenames, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita apply',
          \ 'description': 'Apply a patch to files and/or to the index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<patch>...',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--exclude',
          \ 'don''t apply changes matching the given path',
          \)
    call s:parser.add_argument(
          \ '--include',
          \ 'apply changes matching the given path',
          \)
    call s:parser.add_argument(
          \ '-p',
          \ 'remove <P> leading slashes from traditional diff paths', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ '--no-add',
          \ 'ignore additions made by the patch',
          \)
    call s:parser.add_argument(
          \ '--stat',
          \ 'instead of applying the patch, output diffstat for the input',
          \)
    call s:parser.add_argument(
          \ '--numstat',
          \ 'show number of added and deleted lines in decimal notation',
          \)
    call s:parser.add_argument(
          \ '--summary',
          \ 'instead of applying the patch, output a summary for the input',
          \)
    call s:parser.add_argument(
          \ '--check',
          \ 'instead of applying the patch, see if the patch is applicable',
          \)
    call s:parser.add_argument(
          \ '--index',
          \ 'make sure the patch is applicable to the current index',
          \)
    call s:parser.add_argument(
          \ '--cached',
          \ 'apply a patch without touching the working tree',
          \)
    call s:parser.add_argument(
          \ '--unsafe-paths',
          \ 'accept a patch that touches outside the working area',
          \)
    call s:parser.add_argument(
          \ '--apply',
          \ 'also apply the patch (use with --stat/--summary/--check)', {
          \   'superordinates': ['stat', 'summary', 'check'],
          \})
    call s:parser.add_argument(
          \ '--build-fake-ancestor',
          \ 'build a temporary index based on embedded index information', {
          \   'complete': s:ArgumentParser.complete_files,
          \})
    call s:parser.add_argument(
          \ '-C',
          \ 'ensure at least <C> lines of context match', {
          \   'pattern': '^\d\+$',
          \})
    call s:parser.add_argument(
          \ '--whitespace',
          \ 'detect new or modified lines that have whitespace errors', {
          \   'choices': ['nowarn', 'warn', 'fix', 'error', 'error-all'],
          \})
    call s:parser.add_argument(
          \ '--ignore-whitespace',
          \ 'ignore changes in whitespace when finding context (same as --ignore-space-change)', {
          \   'conflicts': ['ignore-space-change'],
          \})
    call s:parser.add_argument(
          \ '--ignore-space-change',
          \ 'ignore changes in whitespace when finding context (same as --ignore-whitespace)', {
          \   'conflicts': ['ignore-whitespace'],
          \})
    call s:parser.add_argument(
          \ '--reverse', '-R',
          \ 'apply the patch in reverse',
          \)
    call s:parser.add_argument(
          \ '--unidiff-zero',
          \ 'don''t expect at least one line of context',
          \)
    call s:parser.add_argument(
          \ '--reject',
          \ 'leave the rejected hunks in corresponding *.rej files',
          \)
    call s:parser.add_argument(
          \ '--allow-overlap',
          \ 'allow overlapping hunks',
          \)
    call s:parser.add_argument(
          \ '--inaccurate-eof',
          \ 'tolerate incorrectly detected missing new-line at the end of file',
          \)
    call s:parser.add_argument(
          \ '--recount',
          \ 'do not trust the line contents in the hunk headers',
          \)
    call s:parser.add_argument(
          \ '--directory',
          \ 'prepend <DIRECTORY> to all filenames', {
          \   'complete': s:ArgumentParser.complete_files,
          \})
  endif
  return s:parser
endfunction
function! gita#command#apply#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#apply#default_options),
        \ options,
        \)
  call gita#command#apply#call(options)
endfunction
function! gita#command#apply#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#apply', {
      \ 'default_options': {},
      \})
