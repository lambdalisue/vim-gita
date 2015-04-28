"******************************************************************************
" Argument completer of ArgumentParser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort
  let s:P = a:V.import('System.Filepath')
  call extend(self, s:const)
endfunction
function! s:_vital_depends() abort
  return ['System.Filepath']
endfunction


let s:_completers = {}

function! s:new(name, ...) abort " {{{
  if !has_key(s:_completers, a:name)
    throw printf(
          \ 'vital: ArgumentParser.Completer: "%s" is not defined',
          \ a:name,
          \)
  endif
  let instance = call(s:_completers[a:name], a:000)
  let instance.__name__ = a:name
  return instance
endfunction " }}}
function! s:register(name, callback) abort " {{{
  let s:_completers[a:name] = a:callback
endfunction " }}}
function! s:unregister(name) abort " {{{
  unlet! s:_completers[a:name]
endfunction " }}}
function! s:get_completers() abort " {{{
  return deepcopy(s:_completers)
endfunction " }}}
function! s:get_abstract_completer() abort " {{{
  let completer = {
        \ 'candidates': [],
        \}
  function! completer.complete(arglead, cmdline, cursorpos, args) abort
    let candidates = self.gather_candidates(
          \ a:arglead,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:args,
          \)
    let candidates = filter(
          \ deepcopy(candidates),
          \ printf('v:val =~# "^%s"', a:arglead),
          \)
    return candidates
  endfunction
  function! completer.gather_candidates(arglead, cmdline, cursorpos, args) abort
    return self.candidates
  endfunction
  return completer
endfunction " }}}

function! s:_new_file_completer(...) abort " {{{
  let options = extend({
        \ 'base_dir': '.',
        \}, get(a:000, 0, {}))
  let completer = s:get_abstract_completer()
  function! completer.gather_candidates(arglead, cmdline, cursorpos, args) abort
    " Ref: Vital.vim OptionParser.vim
    let candidates = split(
          \ glob(s:P.join(self.base_dir, a:arglead . '*'), 0),
          \ "\n"
          \)
    " substitute 'base_dir'
    call map(candidates, printf("substitute(v:val, '^%s/', '', '')", self.base_dir))
    " substitute /home/<username> to ~/ if ~/ is specified
    if a:arglead =~# '^\~'
      let home_dir = expand('~')
      call map(candidates, printf("substitute(v:val, '^%s', '~', '')", home_dir))
    endif
    call map(candidates, "escape(isdirectory(v:val) ? v:val.'/' : v:val, ' \\')")
    return candidates
  endfunction
  return extend(completer, options)
endfunction " }}}
function! s:_new_choice_completer(...) abort " {{{
  let options = extend({
        \ 'choices': [],
        \}, get(a:000, 0, {}))
  let completer = s:get_abstract_completer()
  function! completer.gather_candidates(arglead, cmdline, cursorpos, args) abort
    return self.choices
  endfunction
  return extend(completer, options)
endfunction " }}}

call s:register('file', function('s:_new_file_completer'))
call s:register('choice', function('s:_new_choice_completer'))

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
