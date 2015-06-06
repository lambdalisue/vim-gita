let s:save_cpo = &cpo
set cpo&vim


" Modules
let s:F = gita#utils#import('System.File')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita browse',
          \ 'description': 'Browse a selected region of the remote in a system default browser',
          \})
    call s:parser.add_argument(
          \ '--open', '-o',
          \ 'Open a selected region in a system default browser', {
          \   'conflicts': ['yank', 'echo'],
          \ })
    call s:parser.add_argument(
          \ '--yank', '-y',
          \ 'Yank a URL of a selected region of the remote', {
          \   'conflicts': ['open', 'echo'],
          \ })
    call s:parser.add_argument(
          \ '--echo', '-e',
          \ 'Echo a URL of a selected region of the remote', {
          \   'conflicts': ['open', 'yank'],
          \ })

    function! s:parser.hooks.pre_validate(opts) abort
      " Automatically use '--open' if no conflicted argument is specified
      if empty(self.get_conflicted_arguments('open', a:opts))
        let a:opts.open = 1
      endif
    endfunction
  endif
  return s:parser
endfunction " }}}

function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:url(opts, ...) abort " {{{
  let filename = expand(get(a:000, 0, '%'))
  let bufname = bufname(filename)
  let gita = s:get_gita(filename)

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#status#s:open',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  endif
  let meta = gita.git.get_meta()
  let data = {}
  let data.path = gita.git.get_relative_path(fnamemodify(filename, ':p'))
  let data.local_branch = meta.current_branch
  let data.local_branch_hash = meta.current_branch_hash
  let data.remote_branch = meta.current_remote_branch
  let data.remote_branch_hash = meta.current_remote_branch_hash
  let data.remote_url = meta.current_remote_url

  if empty(data.remote_branch)
    " use 'master' instead
    let data.remote_branch = 'master'
    let data.remote_branch_hash = gita.git.get_remote_hash(
          \ gita.git.get_branch_remote('master'),
          \ 'master',
          \)
  endif

  " get selected region
  if filename != expand('%')
    let data.line_start = ''
    let data.line_end = ''
  elseif has_key(a:opts, '__range__')
    let data.line_start = a:opts.__range__[0]
    let data.line_end = a:opts.__range__[1]
  elseif get(a:opts, 'multiline', 0)
    let data.line_start = getpos("'<")[1]
    let data.line_end = getpos("'>")[1]
  else
    let data.line_start = getpos(".")[1]
    let data.line_end = ''
  endif
  let data.line_end = data.line_start == data.line_end ? '' : data.line_end
  let format_map = {
        \ 'lb': 'local_branch',
        \ 'lh': 'local_branch_hash',
        \ 'rb': 'remote_branch',
        \ 'rh': 'remote_branch_hash',
        \ 'pt': 'path',
        \ 'ls': 'line_start',
        \ 'le': 'line_end',
        \}
  for pattern in g:gita#features#browse#translation_patterns
    if data.remote_url =~# pattern[0]
      let repl = get(pattern, get(a:opts, 'exact', 0) ? 2 : 1, pattern[1])
      let repl = substitute(data.remote_url, pattern[0], repl, 'g')
      return gita#utils#format_string(repl, format_map, data)
    endif
  endfor
  call gita#utils#debugmsg('URL could not be obtain from: ', data)
  return ''
endfunction " }}}
function! s:open(...) abort " {{{
  let url = call('s:url', a:000)
  if !empty(url)
    call s:F.open(url)
  endif
  return url
endfunction " }}}


" Internal API
function! gita#features#browse#url(...) abort " {{{
  return call('s:url', a:000)
endfunction " }}}
function! gita#features#browse#open(...) abort " {{{
  return call('s:open', a:000)
endfunction " }}}


" External API
function! gita#features#browse#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if get(opts, 'open', 0)
    call s:open(opts)
  elseif get(opts, 'yank', 0)
    call gita#utils#yank_string(s:url(opts))
  elseif get(opts, 'echo', 0)
    echo s:url(opts)
  endif
endfunction " }}}
function! gita#features#browse#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let s:default_translation_patterns =
      \ [
      \  ['\vssh://git\@(github\.com)/([^/]+)/(.+)%(\.git|)',
      \   'https://\1/\2/\3/blob/%rb/%pt%{#L|}ls%{-L|}le',
      \   'https://\1/\2/\3/blob/%rh/%pt%{?at=|}rb%{#L|}ls%{-L|}le'],
      \  ['\vgit\@(github\.com):([^/]+)/(.+)%(\.git|)',
      \   'https://\1/\2/\3/blob/%rb/%pt%{#L|}ls%{-L|}le',
      \   'https://\1/\2/\3/blob/%rh/%pt%{?at=|}rb%{#L|}ls%{-L|}le'],
      \  ['\vhttps?://(github\.com)/([^/]+)/(.+)',
      \   'https://\1/\2/\3/blob/%rb/%pt%{#L|}ls%{-L|}le',
      \   'https://\1/\2/\3/blob/%rh/%pt%{?at=|}rb%{#L|}ls%{-L|}le'],
      \  ['\vgit\@(bitbucket\.org):([^/]+)/(.+)%(\.git|)',
      \   'https://\1/\2/\3/src/%rb/%pt%{#cl-|}ls',
      \   'https://\1/\2/\3/src/%rh/%pt%{?at=|}rb%{#cl-|}ls'],
      \  ['\vhttps?://(bitbucket\.org)/([^/]+)/(.+)',
      \   'https://\1/\2/\3/src/%rb/%pt%{#cl-|}ls',
      \   'https://\1/\2/\3/src/%rh/%pt%{?at=|}rb%{#cl-|}ls'],
      \ ]
let g:gita#features#browse#translation_patterns =
      \ get(g:, 'gita#features#browse#translation_patterns',
      \   extend(s:default_translation_patterns,
      \     get(g:, 'gita#features#browse#extra_translation_patterns', []),
      \   )
      \ )

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
