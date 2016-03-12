let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, filenames, options) abort
  let filenames = map(
        \ copy(a:filenames),
        \ 's:Path.unixpath(s:Git.get_relative_path(a:git, v:val))',
        \)
  let args = gita#util#args_from_options(a:options, {
       \ 'soft': 1,
       \ 'mixed': 1,
       \ 'N': 1,
       \ 'hard': 1,
       \ 'merge': 1,
       \ 'keep': 1,
       \})
  if gita#util#any(a:options, ['soft', 'mixed', 'hard', 'merge', 'keep'])
    let args = ['reset'] + args + [get(a:options, 'commit', '')]
  else
    let args = ['reset'] + args + ['--'] + filenames
  endif
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<paths>...',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--mixed',
          \ 'reset HEAD and index', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--soft',
          \ 'reset only HEAD', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--hard',
          \ 'reset HEAD, index and working tree', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--merge',
          \ 'reset HEAD, index and working tree', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--keep',
          \ 'reset HEAD but keep local changes', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--edit', '-e', [
          \   'open the diff vs. the index in a buffer and let the user edit it.',
          \   'this is an alias option for :Gita patch --one %',
          \], {
          \   'conflicts': [
          \     'patch',
          \     'mixed', 'soft', 'hard', 'merge', 'keep',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--patch', '-p', [
          \   'open the diff vs. the index in two buffers and let the user edit it.',
          \   'this is an alias option for :Gita patch --two %',
          \], {
          \   'conflicts': [
          \     'edit',
          \     'mixed', 'soft', 'hard', 'merge', 'keep',
          \   ],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit of reset target.',
          \   'if nothing is specified, it reset a content of the index to HEAD.',
          \   'if <commit> is specified, it reset a content of the index to the named <commit>.',
          \], {
          \   'complete': function('gita#complete#commit'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#reset#call(...) abort
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

function! gita#command#reset#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#reset#default_options),
        \ options,
        \)
  call gita#option#assign_filenames(options)
  if get(options, 'edit') || get(options, 'patch')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#add#open(options)
  else
    call gita#command#reset#call(options)
  endif
endfunction

function! gita#command#reset#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#reset', {
      \ 'default_options': {},
      \})
