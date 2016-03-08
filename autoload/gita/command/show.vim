let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:WORKTREE = '@@'

function! s:pick_available_options(options) abort
  " Note:
  " Personally 'git show' is used only for showing a content of a particular
  " <refspec> so no options are required to be allowed.
  " Let me know or send me a PR if you need some options to be allowed.
  let options = s:Dict.pick(a:options, [])
  return options
endfunction
function! s:get_ancestor_content(git, commit, filename, options) abort
  let [lhs, rhs] = s:GitTerm.split_range(a:commit)
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let commit = s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
  return s:get_revision_content(a:git, commit, a:filename, a:options)
endfunction
function! s:get_revision_content(git, commit, filename, options) abort
  let options = s:pick_available_options(a:options)
  if empty(a:filename)
    let options['object'] = a:commit
  else
    let options['object'] = join([
          \ a:commit,
          \ s:Path.unixpath(s:Git.get_relative_path(a:git, a:filename)),
          \], ':')
  endif
  let result = gita#execute(a:git, 'show', options)
  if result.status
    call s:GitProcess.throw(result)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#show#call(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'worktree': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  if options.worktree || options.commit ==# s:WORKTREE
    let commit = s:WORKTREE
  else
    let commit = gita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
  endif
  if empty(options.filename)
    let filename = ''
    if commit ==# s:WORKTREE
      call gita#throw('Cannot show a summary of worktree')
    endif
    let content = s:get_revision_content(git, commit, filename, options)
  else
    let filename = gita#variable#get_valid_filename(options.filename)
    if commit ==# s:WORKTREE
      let content = readfile(filename)
    elseif commit =~# '^.\{-}\.\.\..\{-}$'
      let content = s:get_ancestor_content(git, commit, filename, options)
    elseif commit =~# '^.\{-}\.\..\{-}$'
      let commit  = s:GitTerm.split_range(commit)[0]
      let content = s:get_revision_content(git, commit, filename, options)
    else
      let content = s:get_revision_content(git, commit, filename, options)
    endif
  endif
  let result = {
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<path>',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--repository', '-r',
          \ 'show a summary of the repository instead of a file content', {
          \   'conflicts': ['worktree', 'ancestor', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--worktree', '-w',
          \ 'open a content of a file in working tree', {
          \   'conflicts': ['repository', 'ancestor', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ancestor', '-1',
          \ 'open a content of a file in a common ancestor during merge', {
          \   'conflicts': ['repository', 'worktree', 'ours', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--ours', '-2',
          \ 'open a content of a file in our side during merge', {
          \   'conflicts': ['repository', 'worktree', 'ancestor', 'theirs'],
          \})
    call s:parser.add_argument(
          \ '--theirs', '-3',
          \ 'open a content of a file in thier side during merge', {
          \   'conflicts': ['repository', 'worktree', 'ancestor', 'ours'],
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
    call s:parser.add_argument(
          \ '--patch',
          \ 'show a content of a file in PATCH mode. It force to open an INDEX file content', {
          \   'superordinates': ['ui'],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit which you want to see.',
          \   'if nothing is specified, it show a content of the index.',
          \   'if <commit> is specified, it show a content of the named <commit>.',
          \   'if <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'if <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      elseif get(a:options, 'ancestor')
        let a:options.commit = ':1'
        unlet a:options.commit
      elseif get(a:options, 'ours')
        let a:options.commit = ':2'
        unlet a:options.commit
      elseif get(a:options, 'theirs')
        let a:options.commit = ':3'
        unlet a:options.commit
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#show#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#show#default_options),
        \ options,
        \)
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  if get(options, 'ui')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#show#open(options)
  else
    call gita#command#show#call(options)
  endif
endfunction
function! gita#command#show#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#show', {
      \ 'default_options': {},
      \})
