let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:P = gita#utils#import('Prelude')
let s:G = gita#utils#import('VCS.Git')


" Private functions
function! s:new_gita(...) abort " {{{
  let expr = get(a:000, 0, "%")
  let buftype = getbufvar(expr, '&buftype', 'noname')
  if empty(buftype)
    let git = s:G.find(fnamemodify(bufname(expr), ':p'))
    let gita = extend(deepcopy(s:gita), {
          \ 'enabled': !empty(git),
          \ 'bufname': bufname(expr),
          \ 'bufnum': bufnr(expr),
          \ 'cwd': getcwd(),
          \ 'git': git,
          \})
  else
    " Non file buffer. Use a current working directory instead.
    let git = s:G.find(fnamemodify(getcwd(), ':p'))
    let gita = extend(deepcopy(s:gita), {
          \ 'enabled': !empty(git),
          \ 'bufname': bufname(expr),
          \ 'bufnum': bufnr(expr),
          \ 'cwd': getcwd(),
          \ 'git': git,
          \})
  endif
  call setbufvar(expr, '_gita', gita)
  return gita
endfunction " }}}
function! s:get_gita(...) abort " {{{
  let expr = get(a:000, 0, "%")
  let gita = getbufvar(expr, '_gita', {})
  if empty(gita) || (has_key(gita, 'is_expired') && gita.is_expired())
    return s:new_gita(expr)
  else
    return gita
  endif
endfunction " }}}
function! s:parse_args(...) abort " {{{
  if a:0 == 0
    let files = []
    let opts = {}
  elseif a:0 == 1
    if s:P.is_list(a:1)
      let files = a:1
      let opts = {}
    else
      let files = []
      let opts = a:1
    endif
  else
    let files = a:1
    let opts = a:2
  endif
  return [files, opts]
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
function! s:gita.is_enabled_with_warn() abort " {{{
  if !get(self, 'enabled', 0)
    call gita#utils#warn(
          \ 'vim-gita: Gita is not available in the current buffer',
          \)
    return 0
  endif
  return 1
endfunction " }}}
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
function! s:gita.get_parsed_statuses(...) abort " {{{
  let [files, opts] = call('s:parse_args', a:000)
  if !self.enabled
    return []
  endif
  let args = [
        \ 'status', 
        \ '--porcelain',
        \ '--ignore-submodules=all',  " to improve the response of the command
        \]
  if !empty(files)
    let args = args + ['--'] + self.get_absolute_paths(files)
  endif
  let stdout = gita.exec(args, opts)
  if empty(stdout)
    return {}
  endif
  let statuses = s:S.parse(stdout)
  return statuses
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
