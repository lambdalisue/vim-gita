function! s:action(candidate, options) abort
  let options = extend({
        \ 'merge': 0,
        \}, a:options)
  let git = gita#core#get_or_fail()
  let args = [
        \ 'rebase',
        \ options.merge ? '--merge': '',
        \ a:candidate.name,
        \]
  let args = filter(args, '!empty(v:val)')
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! gita#action#rebase#define(disable_mapping) abort
  call gita#action#define('rebase', function('s:action'), {
        \ 'description': 'Rebase HEAD from the commit (fast-forward)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('rebase:merge', function('s:action'), {
        \ 'description': 'Rebase HEAD by merging the commit',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'merge': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
