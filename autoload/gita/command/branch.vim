let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Prompt = s:V.import('Vim.Prompt')
let s:StringExt = s:V.import('Data.StringExt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'delete',
        \ 'D',
        \ 'create-reflog',
        \ 'force',
        \ 'move',
        \ 'M',
        \ 'remotes',
        \ 'all',
        \ 'list',
        \ 'track', 'no-track',
        \ 'set-upstream', 'set-upstream-to', 'unset-upstream',
        \ 'contains',
        \ 'merged', 'no-merged',
        \ 'branchname',
        \ 'start-point',
        \ 'oldbranch',
        \ 'newbranch',
        \])
  return options
endfunction
function! s:get_branch_content(git, options) abort
  let options = s:pick_available_options(a:options)
  let options['no-column'] = 1
  let options['no-color'] = 1
  let options['no-abbrev'] = 1
  let result = gita#execute(a:git, 'branch', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! s:format_branch(branch) abort
  return a:branch.record
endfunction
function! s:format_branches(branches) abort
  return map(copy(a:branches), 's:format_branch(v:val)')
endfunction
function! s:get_header_string(git) abort
  let branches = gita#get_meta('branches', [])
  let nbranches = len(branches)
  return printf(
        \ 'There are %d branch%s %s',
        \ nbranches,
        \ nbranches == 1 ? '' : 'es',
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let candidates = gita#get_meta('branches', [])
  return index >= 0 ? get(candidates, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#branch#edit()
  endfunction

  call gita#action#includes(
        \ g:gita#command#branch#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \])

  if g:gita#command#branch#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#branch#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#branch#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#branch#bufname(options) abort
  let options = extend({
        \ 'list': '',
        \ 'all': 0,
        \ 'remotes': 0,
        \}, a:options)
  let git = gita#get_or_fail()
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'branch',
        \ 'extra_options': [
        \   empty(options.list) ? '' : options.list,
        \   empty(options.all) ? '' : 'all',
        \   empty(options.remotes) ? '' : 'remotes',
        \ ],
        \ 'commitish': '',
        \ 'path': '',
        \})
endfunction
function! gita#command#branch#call(...) abort
  let options = gita#option#init('^branch$', get(a:000, 0, {}), {
        \ 'all': 0,
        \ 'remotes': 0,
        \})
  let git = gita#get_or_fail()
  let content = s:get_branch_content(git, options)
  if options.remotes
    let content = map(
          \ content,
          \ 'substitute(v:val, "^\\(..\\)", "\\1remotes/", "")'
          \)
  endif
  let branches = s:GitParser.parse_branch(content)
  let result = {
        \ 'content': content,
        \ 'branches': branches,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#branch#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#branch#default_opener
        \ : options.opener
  let bufname = gita#command#branch#bufname(options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#branch#edit(options)
endfunction
function! gita#command#branch#edit(...) abort
  let options = gita#option#init('^branch$', {}, get(a:000, 0, {}))
  let options['quiet'] = 1
  let result = gita#command#branch#call(options)
  call gita#set_meta('content_type', 'branch')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'quiet',
        \]))
  call gita#set_meta('branches', result.branches)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_branch
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> nested call s:on_BufReadCmd()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-branch
  setlocal buftype=nofile nobuflisted
  setlocal nowrap
  setlocal cursorline
  setlocal nomodifiable
  call gita#command#branch#redraw()
endfunction
function! gita#command#branch#redraw() abort
  let git = gita#get_or_fail()
  let prologue = s:List.flatten([
        \ [s:get_header_string(git)],
        \ gita#action#mapping#get_visibility()
        \   ? map(gita#action#get_mapping_help(), '"| " . v:val')
        \   : []
        \])
  let branches = gita#get_meta('branches', [])
  let contents = s:format_branches(branches)
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita branch',
          \ 'description': 'List, create, or delete branches',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--track', '-t',
          \ 'set up tracking mode (see git-pull(1))',
          \)
    call s:parser.add_argument(
          \ '--set-upstream-to', '-u',
          \ 'change the upstram info', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--unset-upstraem',
          \ 'unset the upstream info',
          \)
    call s:parser.add_argument(
          \ '--remotes', '-r',
          \ 'act on remote-tracking branches',
          \)
    call s:parser.add_argument(
          \ '--contains',
          \ 'print only branches that contains the commit', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'list both remote-tracking and local branches',
          \)
    call s:parser.add_argument(
          \ '--delete', '-d',
          \ 'delete fully merged branch',
          \)
    call s:parser.add_argument(
          \ '-D',
          \ 'delete branch (even if not merged)',
          \)
    call s:parser.add_argument(
          \ '--move', '-m',
          \ 'move/rename a branch and its reflog',
          \)
    call s:parser.add_argument(
          \ '-M',
          \ 'move/rename a branch, even if target exists',
          \)
    call s:parser.add_argument(
          \ '--list',
          \ 'list branch names',
          \)
    call s:parser.add_argument(
          \ '--create-reflog', '-l',
          \ 'create the branch''s reflog',
          \)
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'force creation, mov/rename, deletion',
          \)
    call s:parser.add_argument(
          \ '--no-merged',
          \ 'print only not merged branches', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--merged',
          \ 'print only merged branches', {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction
function! gita#command#branch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#branch#default_options),
        \ options,
        \)
  call gita#command#branch#open(options)
endfunction
function! gita#command#branch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#branch#define_highlights() abort
  highlight default link GitaComment    Comment
  highlight default link GitaSelected   Special
  highlight default link GitaRemote     Constant
endfunction
function! gita#command#branch#define_syntax() abort
  syntax match GitaComment    /\%^.*$/
  syntax match GitaSelected   /^\* [^ ]\+/hs=s+2
  syntax match GitaRemote     /^..remotes\/[^ ]\+/hs=s+2
endfunction

call gita#util#define_variables('command#branch', {
      \ 'default_options': {},
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'enable_default_mappings': 1,
      \})
