let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:A = gita#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita[!] rm',
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
function! s:parser.hooks.post_validate(options) abort " {{{
  if !get(a:options, 'verbose', 0)
    let a:options.quiet = 1
  else
    unlet a:options.verbose
  endif
endfunction " }}}
function! s:parser.hooks.post_complete_optional_argument(candidates, options) abort " {{{
  let candidates = s:L.flatten([
        \ gita#utils#completes#complete_staged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_unstaged_files('', '', [0, 0], a:options),
        \ a:candidates,
        \])
  return candidates
endfunction " }}}


function! gita#features#rm#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    " git store files with UNIX type path separation (/)
    let options['--'] = gita#utils#path#unix_abspath(options['--'])
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
function! gita#features#rm#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#rm#default_options),
          \ options)
    if !empty(options.__unknown__)
      let options['--'] = options.__unknown__
    endif
    call gita#action#exec('rm', options.__range__, options, { 'echo': 'both' })
  endif
endfunction " }}}
function! gita#features#rm#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#rm#action(candidates, options, config) abort " {{{
  if empty(a:candidates)
    return
  endif
  let options = extend({
        \ '--': map(a:candidates, 'v:val.path'),
        \ 'quiet': 1,
        \}, a:options)
  call gita#features#rm#exec(options, extend({
        \ 'echo': 'fail',
        \}, a:config))
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
