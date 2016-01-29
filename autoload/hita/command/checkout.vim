let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'q', 'quiet',
        \ 'f', 'force',
        \ 'ours', 'theirs',
        \ 'b', 'B',
        \ 't', 'track', 'no-track',
        \ 'l',
        \ 'detach',
        \ 'orphan',
        \])
  return options
endfunction
function! s:apply_command(hita, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['commit'] = a:commit
  if !empty(a:filenames)
    let options['--'] = map(
          \ copy(a:filenames),
          \ 's:Path.unixpath(s:Git.get_relative_path(a:hita, v:val))',
          \)
  endif
  let result = hita#execute(a:hita, 'checkout', options)
  if result.status
    call hita#throw(result.stdout)
  endif
  return result.content
endfunction

function! hita#command#checkout#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filenames': [],
        \})
  try
    let hita = hita#get_or_fail()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    if empty(options.filenames)
      let filenames = []
    else
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
    endif
    let content = s:apply_command(hita, commit, filenames, options)
    silent call hita#util#doautocmd('StatusModified')
    return {
          \ 'commit': commit,
          \ 'filenames': filenames,
          \ 'content': content,
          \}
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita checkout',
          \ 'description': 'Checkout a branch or paths to the working tree',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q',
          \ 'Quiet, suppress feedback messages.',
          \)
    call s:parser.add_argument(
          \ '--force', '-f', [
          \   'When switching branches, proceed even if the index or the working',
          \   'tree differs from HEAD. This is used to throw away local changes.',
          \   'When checking out paths from the index, do not fail upon unmerged',
          \   'entries; instead, unmerged entries are ignored.',
          \])
    call s:parser.add_argument(
          \ '--ours', [
          \   'When checking out paths from the index, check out stage #2 from',
          \   'unmerged path.',
          \ ]
          \,{
          \   'conflicts': ['theirs'],
          \})
    call s:parser.add_argument(
          \ '--theirs', [
          \   'When checking out paths from the index, check out stage #3 from',
          \   'unmerged path.',
          \ ]
          \,{
          \   'conflicts': ['ours'],
          \})
    call s:parser.add_argument(
          \ '-b', [
          \   'Create a new branch with a specified name and start it at <start_point>.',
          \ ], {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': ['B', 'orphan'],
          \})
    call s:parser.add_argument(
          \ '-B', [
          \   'Create a new branch with a specified name and start it at <start_point>.',
          \   'If it already exists, then reset it to <start_point>.',
          \ ], {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': ['b', 'orphan'],
          \})
    call s:parser.add_argument(
          \ '--track', '-t', [
          \   'When creating a new branch set up "upstream" configuration.',
          \ ], {
          \   'conflicts': ['--no-track'],
          \})
    call s:parser.add_argument(
          \ '--no-track', [
          \   'Do not set up "upstream" configuration, even if the branch.autosetupmerge',
          \   'configuration variable is true.',
          \ ], {
          \   'conflicts': ['--track'],
          \})
    call s:parser.add_argument(
          \ '-l', [
          \   'Create the new branch''s reflog.',
          \])
    call s:parser.add_argument(
          \ '--detach', [
          \   'Rather than checking out a branch to work on it, check out a commit for',
          \   'inspection and discardable experiments.',
          \   'This is the default behavior of "git checkout <commit>" when <commit>',
          \   'is not a branch name.',
          \])
    call s:parser.add_argument(
          \ '--orphan', [
          \   'Create a new orphan branch, started from <start_point> and switch to it.',
          \   'The first commit made on this new branch will have no parents',
          \   'and it will be the root of a new history totally disconnected from all',
          \   'the other branches and commits.',
          \ ], {
          \   'type': s:ArgumentParser.types.value,
          \   'conflicts': ['b', 'B'],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   '<branch> to checkout or <start_point> of a new branch or <tree-ish> to checkout from.',
          \ ], {
          \   'complete': function('hita#variable#complete_commit'),
          \ })
  endif
  return s:parser
endfunction
function! hita#command#checkout#command(...) abort
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
        \ deepcopy(g:hita#command#checkout#default_options),
        \ options,
        \)
  call hita#command#checkout#call(options)
endfunction
function! hita#command#checkout#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#checkout', {
      \})


