let s:V = vital#of('vim_gita')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitInfo = s:V.import('Git.Info')
let s:GitProcess = s:V.import('Git.Process')

function! gita#vital() abort
  return s:V
endfunction

function! gita#throw(...) abort
  let msg = join(a:000)
  throw printf('vim-gita: %s', msg)
endfunction

function! gita#execute(git, args, ...) abort
  call s:GitProcess.set_config({
        \ 'executable': g:gita#executable,
        \ 'arguments':  g:gita#arguments,
        \})
  let args = filter(copy(a:args), '!empty(v:val)')
  let options = extend({
        \ 'quiet': 0,
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  let result = s:GitProcess.execute(a:git, args, s:Dict.omit(options, [
        \ 'quiet', 'fail_silently'
        \]))
  if !options.fail_silently && !result.success
    call s:GitProcess.throw(result)
  elseif !options.quiet
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#get_git_version() abort
  if exists('s:git_version')
    return s:git_version
  endif
  let s:git_version = s:GitInfo.get_git_version()
  return s:git_version
endfunction

function! s:is_debug() abort
  " Used to tell if gita is in debug mode
  return &verbose
endfunction

function! s:is_batch() abort
  " Used to tell if gita is in batch mode (test mode)
  return g:gita#test
endfunction

call s:Prompt.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
call gita#util#define_variables('', {
      \ 'test': 0,
      \ 'develop': 1,
      \ 'executable': 'git',
      \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
      \ 'complete_threshold': 100,
      \})
