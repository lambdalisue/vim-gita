let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
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
          \ '--recursive', '-r',
          \ 'Allow recursive removal when a leading directory name is given.',
          \)
    call s:parser.add_argument(
          \ '--cached', [
          \   'Use this option to unstage and remove path only from the index.',
          \   'Working tree files, whether modified or not, will be left alone.',
          \])
    call s:parser.add_argument(
          \ '--quiet', '-q', [
          \   'Gita rm normally outputs one line (in the form of an rm command) for each file removed.',
          \   'This option suppresses that output.',
          \])
    " A hook function to convert 'verbose' to 'quiet'
    function! s:parser.hooks.post_validate(opts) abort
      if !get(a:opts, 'verbose', 0)
        let a:opts.quiet = 1
      else
        unlet a:opts.verbose
      endif
    endfunction
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


function! gita#features#rm#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
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
  let options = s:D.pick(options, [
        \ '--',
        \ 'q', 'quiet',
        \ 'f', 'force',
        \ 'r', 'recursive',
        \ 'cached',
        \])
  return gita.operations.rm(options, config)
endfunction " }}}
function! gita#features#rm#action(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \}, a:options)
  call gita#features#add#exec(options, {
        \ 'echo': 'fail',
        \})
endfunction " }}}
function! gita#features#rm#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let result = gita#features#rm#exec(extend({
          \ '--': get(options, '__unknown__', []),
          \}, options))
    if len(result.stdout)
      call gita#utils#infomsg(result.stdout)
    endif
  endif
endfunction " }}}
function! gita#features#rm#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
