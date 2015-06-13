let s:save_cpo = &cpo
set cpo&vim


let s:P = gita#utils#import('Prelude')


function! s:translate_option(key, val, scheme) abort " {{{
  if s:P.is_number(a:val)
    if a:val == 0
      return ''
    endif
    let val = ''
  else
    let val = a:val
  endif
  if len(a:key) == 1
    let format = empty(a:scheme) ? '-%k%v' : a:scheme
  else
    let format = empty(a:scheme) ? '--%K%{=}V' : a:scheme
  endif
  let format_map = {
        \ 'k': 'key',
        \ 'v': 'val',
        \ 'K': 'escaped_key',
        \ 'V': 'escaped_val',
        \}
  let data = {
        \ 'key': a:key,
        \ 'val': val,
        \ 'escaped_key': substitute(a:key, '_', '-', 'g'),
        \ 'escaped_val': len(val) ? shellescape(val) : '',
        \}
  return gita#utils#format_string(format, format_map, data)
endfunction " }}}
function! s:translate_options(options, schemes) abort " {{{
  let args = []
  for [key, val]  in items(a:options)
    if key !~# '^__.\+__$' && key !~# '\v%(--|fail_silently)'
      let scheme = get(a:schemes, key, '')
      call add(args, s:translate_option(key, val, scheme))
    endif
    unlet! val
  endfor
  if has_key(a:options, '--')
    call add(args, '--')
    for str in a:options['--']
      call add(args, fnameescape(expand(str)))
    endfor
  endif
  return args
endfunction " }}}
function! s:new(gita) abort " {{{
  let operations = extend(deepcopy(s:operations), {
        \ 'gita': a:gita,
        \})
  return operations
endfunction " }}}


let s:operations = {}
function! s:operations.exec_raw(args, ...) abort " {{{
  let args = filter(deepcopy(a:args), 'len(v:val)')
  let config = extend({
        \ 'echo': 'both',
        \ 'doautocmd': 1,
        \}, get(a:000, 0, {}))
  let result = self.gita.git.exec(args)
  " remove ANSI sequences in case
  let result.stdout = substitute(result.stdout, '\e\[\d\{1,3}[mK]', '', 'g')
  " echo result
  if config.echo =~# '^\%(both\|success\)' && result.status == 0
    call gita#utils#title(printf(
          \ 'vim-gita: Ok: %s', join(result.args),
          \))
    call gita#utils#info(result.stdout)
  elseif config.echo =~# '^\%(both\|fail\)' && result.status != 0
    call gita#utils#error(printf(
          \ 'vim-gita: Fail: %s', join(result.args),
          \))
    call gita#utils#info(result.stdout)
  endif
  " call autocmd
  if config.doautocmd && result.status == 0
    call gita#utils#doautocmd(printf('%s-post', args[0]))
  endif
  return result
endfunction " }}}
function! s:operations.exec(command, options, ...) abort " {{{
  let schemes = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let args = s:translate_options(a:options, schemes)
  let args = extend([a:command], args)
  return self.exec_raw(args, config)
endfunction " }}}
function! s:operations.init(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  return self.exec('init', options, {}, config)
endfunction " }}}
function! s:operations.add(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  return self.exec('add', options, {}, config)
endfunction " }}}
function! s:operations.rm(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  return self.exec('rm', options)
endfunction " }}}
function! s:operations.reset(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'commit': '%v',
        \}
  return self.exec('reset', options, schemes, config)
endfunction " }}}
function! s:operations.show(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'object': '%v',
        \}
  return self.exec('show', options, schemes, config)
endfunction " }}}
function! s:operations.diff(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'commit': '%v',
        \}
  return self.exec('diff', options, schemes, config)
endfunction " }}}
function! s:operations.clone(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'reference': '--%K %V',
        \ 'o': '-%K %V',
        \ 'origin': '--%K %V',
        \ 'b': '-%K %V',
        \ 'branch': '--%K %V',
        \ 'u': '-%K %V',
        \ 'upload_pack': '--%K %V',
        \ 'c': '-%K %V',
        \ 'configig': '--%K %V',
        \ 'depth': '--%K %V',
        \}
  let args = s:translate_options(options, schemes)
  let args = extend(extend(['clone'], args), [
        \ '--',
        \ get(options, 'repository', ''),
        \ get(options, 'directory', ''),
        \])
  return self.exec_raw(args, config)
endfunction " }}}
function! s:operations.status(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  return self.exec('status', options, {}, config)
endfunction " }}}
function! s:operations.commit(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'C': '-%k %v',
        \ 'c': '-%k %v',
        \ 'F': '-%k %v',
        \ 'm': '-%k %v',
        \ 't': '-%k %v',
        \}
  return self.exec('commit', options, schemes, config)
endfunction " }}}
function! s:operations.branch(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'u': '-%k %v',
        \ 'contains': '--%k %v',
        \ 'merged': '--%k %v',
        \ 'no_merged': '--%k %v',
        \}
  return self.exec('branch', options, schemes, config)
endfunction " }}}
function! s:operations.checkout(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  let schemes = {
        \ 'b': '-%k %v',
        \ 'B': '-%k %v',
        \ 'commit': '%v',
        \}
  return self.exec('checkout', options, schemes, config)
endfunction " }}}


" Internal
function! gita#operations#_translate_option(...) abort " {{{
  return call('s:translate_option', a:000)
endfunction " }}}
function! gita#operations#_translate_options(...) abort " {{{
  return call('s:translate_options', a:000)
endfunction " }}}


" Public
function! gita#operations#new(...) abort " {{{
  return call('s:new', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
