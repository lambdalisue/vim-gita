let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'force',
        \ 'dry-run',
        \ 'r',
        \ 'cached',
        \ 'ignore-unmatch',
        \])
  return options
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = a:options
  " NOTE: git rm does not understand 'recursive' so translate
  if has_key(options, 'recursive')
    let options['r'] = options.recursive
  endif
  let options = s:pick_available_options(options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'rm', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#rm#call(...) abort
  let options = gita#option#cascade('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)',
          \)
  endif
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
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<file>...',
          \ 'complete_threshold': g:gita#complete_threshold,
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
function! gita#command#rm#command(...) abort
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
        \ deepcopy(g:gita#command#rm#default_options),
        \ options,
        \)
  call gita#command#rm#call(options)
endfunction
function! gita#command#rm#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#rm', {
      \ 'default_options': {},
      \})

