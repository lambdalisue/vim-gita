let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, filenames, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'force': 1,
        \ 'dry-run': 1,
        \ 'r': 1,
        \ 'cached': 1,
        \ 'ignore-unmatch': 1,
        \})
  if !has_key(a:options, 'r') && get(a:options, 'recursive')
    let args += ['-r']
  endif
  let args = ['rm'] + args + ['--'] + a:filenames
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<file>...',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run',
          \)
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'override the up-to-date check',
          \)
    call s:parser.add_argument(
          \ '--recursive', '-r',
          \ 'allow recursive removal',
          \)
    call s:parser.add_argument(
          \ '--cached',
          \ 'only remove from the index',
          \)
    call s:parser.add_argument(
          \ '--ignore-unmatch',
          \ 'exit with a zero status even if nothing matched',
          \)
  endif
  return s:parser
endfunction


function! gita#command#rm#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(v:val)',
        \)
  let content = s:execute_command(git, filenames, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! gita#command#rm#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#rm#default_options),
        \ options,
        \)
  call gita#option#assin_filenames(options)
  call gita#command#rm#call(options)
endfunction

function! gita#command#rm#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#rm', {
      \ 'default_options': {},
      \})

