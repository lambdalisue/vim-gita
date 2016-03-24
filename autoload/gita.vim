let s:V = vital#of('vim_gita')
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitInfo = s:V.import('Git.Info')
let s:GitProcess = s:V.import('Git.Process')

function! gita#vital() abort
  return s:V
endfunction

function! gita#throw(msg) abort
  throw 'vim-gita: ' . a:msg
endfunction

function! gita#get_git_version() abort
  if exists('s:git_version')
    return s:git_version
  endif
  let s:git_version = s:GitInfo.get_git_version()
  return s:git_version
endfunction

function! gita#execute(git_or_args, ...) abort
  if s:Prelude.is_dict(a:git_or_args)
    let git = a:git_or_args
    let args = a:1
    let options = get(a:000, 1, {})
  else
    let git = gita#core#get()
    let args = a:git_or_args
    let options = get(a:000, 0, {})
  endif
  return gita#command#execute(git, args, options)
endfunction

call gita#util#define_variables('', {
      \ 'test': 0,
      \ 'develop': 1,
      \ 'executable': 'git',
      \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
      \ 'complete_threshold': 100,
      \})

call s:Prompt.set_config({
      \ 'batch': g:gita#test,
      \})

call s:GitProcess.set_config({
      \ 'executable': g:gita#executable,
      \ 'arguments':  g:gita#arguments,
      \})
