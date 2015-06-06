let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:P = gita#utils#import('Prelude')
let s:G = gita#utils#import('VCS.Git')
let s:S = gita#utils#import('VCS.Git.StatusParser')


" Private functions
function! s:new_gita(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let buftype = getbufvar(expr, 'buftype')
  if empty(buftype) && !empty(bufname)
    let git = s:G.find(fnamemodify(bufname, ':p'))
  elseif !buflisted(bufname) && filereadable(expand(expr))
    let git = s:G.find(fnamemodify(expand(expr), ':p'))
  else
    " Non file buffer. Use a current working directory instead.
    let git = s:G.find(fnamemodify(getcwd(), ':p'))
  endif
  let gita = extend(deepcopy(s:gita), {
        \ 'enabled': !empty(git),
        \ 'bufname': bufname,
        \ 'bufnum':  bufnr('%'),
        \ 'cwd':     getcwd(),
        \ 'git':     git,
        \})
  let gita.operations = gita#operations#new(gita)
  call setbufvar(expr, '_gita', gita)
  return gita
endfunction " }}}
function! s:get_gita(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = getbufvar(expr, '_gita', {})
  if empty(gita) || (has_key(gita, 'is_expired') && gita.is_expired())
    let gita = s:new_gita()
  endif
  return gita
endfunction " }}}


" Public functions
function! gita#core#new(...) abort " {{{
  " return a new gita instance
  return call('s:new_gita', a:000)
endfunction " }}}
function! gita#core#get(...) abort " {{{
  " return a cached or new gita instance
  return call('s:get_gita', a:000)
endfunction " }}}


" Gita instance
let s:gita = {}
function! s:gita.is_expired() abort " {{{
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = getbufvar(bufnum, '&buftype')
  if empty(buftype) && bufname !=# get(self, 'bufname', '')
    return 1
  elseif !empty(buftype) && getcwd() !=# self.cwd
    return 1
  else
    return 0
  endif
endfunction " }}}
function! s:gita.get_parsed_status(...) abort " {{{
  let options = extend({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, get(a:000, 0, {}))
  let result = self.operations.status(options)
  if result.status == 0
    return s:S.parse(result.stdout)
  endif
  return result
endfunction " }}}
function! s:gita.get_parsed_commit(...) abort " {{{
  let options = extend({
        \ 'porcelain': 1,
        \ 'dry_run',
        \ 'no_status',
        \ 'ignore_submodules': 1,
        \}, get(a:000, 0, {}))
  let result = self.operations.commit(options)
  if result.status == 1
    return s:S.parse(result.stdout)
  endif
  return result
endfunction " }}}

" Obsolute
function! s:gita.exec(args, ...) abort " {{{
  let args = deepcopy(a:args)
  let opts = get(a:000, 0, {})
  let result = self.git.exec(args, opts)
  if result.status
    call gita#utils#errormsg(printf(
          \ 'vim-gita: Fail: %s', join(result.args)
          \))
    call gita#utils#infomsg(result.stdout)
  else
    call gita#utils#doautocmd(printf('%s-post', args[0]))
  endif
  return result
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
