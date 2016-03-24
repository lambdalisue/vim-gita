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

function! gita#execute(git, args, options) abort
  let options = extend({
        \ 'quiet': 0,
        \ 'fail_silently': 0,
        \ 'success_status': 0,
        \}, a:options)
  let args = filter(copy(a:args), '!empty(v:val)')
  let result = s:GitProcess.execute(a:git, args, s:Dict.omit(options, [
        \ 'quiet', 'fail_silently'
        \]))
  if !options.fail_silently && result.status != options.success_status
    call s:GitProcess.throw(result)
  elseif !options.quiet
    call s:Prompt.debug('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
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
