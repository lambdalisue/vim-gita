let s:save_cpo = &cpo
set cpo&vim


let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Override the up-to-date check.',
          \)
    call s:parser.add_argument(
          \ '--dry-run', '-n', [
          \   'Don''t actually remove any file(s). Instead, just show if they exist in the index',
          \   'and would otherwise be removed by the comand.',
          \])
    call s:parser.add_argument(
          \ '--recursive', '-r',
          \ 'Allow recursive removal when a leading directory name is given.',
          \)
    call s:parser.add_argument(
          \ '--cached', [
          \   'Use this option to unstage and remove path only from the index.',
          \   'Working tree files, whether modified or not, will be left alone.',
          \])
    call s:parser.add_argument(
          \ '--ignore-unmatch',
          \ 'Exit with a zero status even if no files matched.',
          \)
    call s:parser.add_argument(
          \ '--quiet', '-q', [
          \   'Gita rm normally outputs one line (in the form of an rm command) for each file removed.',
          \   'This option suppresses that output.',
          \])

    " A hook function to display staged/unstaged (tracked) files in completions
    function! s:parser.hooks.post_complete_optional_argument(candidates, opts) abort
      let gita = s:get_gita()
      let statuses = gita.get_parsed_status()
      let candidates = deepcopy(extend(
            \ get(statuses, 'staged', []),
            \ get(statuses, 'unstaged', []),
            \))
      let candidates = filter(
            \ map(candidates, 'get(v:val, ''path'', '''')'),
            \ 'len(v:val) && index(a:opts.__unknown__, v:val) == -1',
            \)
      let candidates = extend(
            \ a:candidates,
            \ candidates,
            \)
      return candidates
    endfunction
  endif
  return s:parser
endfunction " }}}
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:exec(...) abort " {{{
  let gita = s:get_gita()
  let options = get(a:000, 0, {})
  " automatically specify the current buffer if nothing is specified
  " and the buffer is a file buffer
  if empty(&buftype) && empty(get(options, '--', []))
    let options['--'] = ['%']
  endif
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#add#s:exec',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  endif
  return gita.operations.rm(options)
endfunction " }}}


" Internal API
function! gita#features#rm#exec(...) abort " {{{
  return call('s:exec', a:000)
endfunction " }}}


" External API
function! gita#features#rm#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  let options['--'] = get(options, '__unknown__', [])
  let result = s:exec(options)
  if len(result.stdout)
    call gita#utils#infomsg(result.stdout)
  endif
endfunction " }}}
function! gita#features#rm#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
