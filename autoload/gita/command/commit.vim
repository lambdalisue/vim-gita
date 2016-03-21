let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:is_untracked_files_supported() abort
  if exists('s:untracked_files_supported')
    return s:untracked_files_supported
  endif
  " remove -u/--untracked-files which requires Git >= 1.4
  let s:untracked_files_supported = gita#get_git_version() !~# '^-\|^1\.[1-3]\.' 
  return s:untracked_files_supported
endfunction

function! s:execute_command(git, filenames, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'all': 1,
        \ 'reset-author': 1,
        \ 'file': 1,
        \ 'author': 1,
        \ 'date': 1,
        \ 'message': 1,
        \ 'allow-empty': 1,
        \ 'allow-empty-message': 1,
        \ 'amend': 1,
        \ 'untracked-files': 1,
        \ 'dry-run': 1,
        \ 'gpg-sign': 1,
        \ 'no-gpg-sign': 1,
        \ 'porcelain': 1,
        \})
  if s:is_untracked_files_supported() && has_key(a:options, 'untracked-files')
    let args += ['--untracked-files']
  endif
  let args = ['commit', '--verbose'] + args + ['--'] + a:filenames
  " NOTE:
  " 'git commit' always returns 1 when --dry-run is specified
  let options = extend(copy(a:options), {
        \ 'fail_silently': get(a:options, 'dry-run'),
        \})
  return gita#execute(a:git, args, s:Dict.pick(options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita commit',
          \ 'description': 'Show a status of the repository',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': 'files to index for commit',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--author',
          \ 'override author for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--date',
          \ 'override date for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--message', '-m',
          \ 'commit message. imply --no-ui', {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': ['ui'],
          \})
    call s:parser.add_argument(
          \ '--gpg-sign', '-S',
          \ 'GPG sign commit', {
          \   'type': s:ArgumentParser.types.any,
          \   'conflicts': ['no-gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--no-gpg-sign',
          \ 'no GPG sign commit', {
          \   'conflicts': ['gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit',
          \)
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'commit all changed files',
          \)
    call s:parser.add_argument(
          \ '--allow-empty',
          \ 'allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--allow-empty-message',
          \ 'allow an empty commit message',
          \)
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'reset author for commit',
          \)
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no', {
          \   'choices': ['all', 'normal', 'no'],
          \   'on_default': 'all',
          \})
    call s:parser.add_argument(
          \ '--ui',
          \ 'show a buffer instead of echo the result. imply --quiet', {
          \   'deniable': 1,
          \   'conflicts': ['message'],
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
    function! s:parser.hooks.pre_complete(options) abort
      if empty(s:parser.get_conflicted_arguments('ui', a:options))
        let a:options.ui = 1
      endif
    endfunction
    function! s:parser.hooks.pre_validate(options) abort
      if empty(s:parser.get_conflicted_arguments('ui', a:options))
        let a:options.ui = 1
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction


function! gita#command#commit#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \ 'amend': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(git, v:val)',
        \)
  let content = s:execute_command(git, filenames, options)
  let result = {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! gita#command#commit#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#commit#default_options),
        \ options,
        \)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#ui#commit#open(options)
  else
    call gita#command#commit#call(options)
  endif
endfunction

function! gita#command#commit#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#commit', {
      \ 'default_options': { 'untracked-files': 1 },
      \})
