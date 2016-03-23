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
        \ 'untracked-files': 1,
        \ 'ignore-submodules': 1,
        \ 'ignored': 1,
        \ 'porcelain': 1,
        \})
  if s:is_untracked_files_supported() && has_key(a:options, 'untracked-files')
    let args += ['--untracked-files']
  endif
  let args = ['status', '--no-column'] + args + ['--'] + a:filenames
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita status',
          \ 'description': 'Show and manipulate a status of the repository',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': 'filenames',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files as well'
          \)
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules when looking for changes', {
          \   'choices': ['none', 'untracked', 'dirty', 'all'],
          \   'on_default': 'all',
          \})
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no', {
          \   'choices': ['all', 'normal', 'no'],
          \   'on_default': 'all',
          \})
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

function! gita#command#status#call(...) abort
  let options = extend({
        \ 'filenames': [],
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

function! gita#command#status#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#status#default_options),
        \ options,
        \)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#ui#status#open(options)
  else
    call gita#command#status#call(options)
  endif
endfunction

function! gita#command#status#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#status', {
      \ 'default_options': { 'untracked-files': 1 },
      \})
