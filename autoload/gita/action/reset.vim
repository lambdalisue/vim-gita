let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! s:action(candidates, options) abort
  let git = gita#core#get_or_fail()
  let args = ['reset']
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 's:Path.unixpath(s:Git.get_relative_path(git, v:val.path))',
        \)
  call gita#command#execute(args, { 'quiet': 1 })
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#action#reset#define(disable_mappings) abort
  call gita#action#define('reset', function('s:action'), {
        \ 'description': 'Reset changes on the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
endfunction
