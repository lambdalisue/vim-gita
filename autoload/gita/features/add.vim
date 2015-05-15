let s:save_cpo = &cpo
set cpo&vim


let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_validator() abort " {{{
  if !exists('s:validator') || get(g:, 'gita#debug', 0)
    let s:validator = gita#utils#validator#new({ 'name': 'add' })
    function! s:validator.validate(status, option) abort
      if a:status.is_ignored && !get(a:option, 'force', 0)
        call gita#utils#warn(printf(
              \ 'An ignored file "%s" cannot be added. Use --force option to force it.',
              \ a:status.path,
              \))
        return 1
      elseif a:status.is_conflicted
        if a:status.sign ==# 'DD'
          call gita#utils#warn(printf(
                \ 'A both deleted conflict file "%s" cannot be added. Use :Gita rm instead.',
                \ a:status.path,
                \))
          return 1
        else
          return 0
        endif
      else
        call gita#utils#warn(printf(
              \ 'No changes of "%s" exist on working tree.',
              \ a:status.path,
              \))
        return 1
      endif
    endfunction
  endif
  return s:validator
endfunction " }}}
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita add',
          \ 'description': 'Add changes to index',
          \})
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run',
          \)
    call s:parser.add_argument(
          \ '--all', '-A',
          \ 'add changes from all tracked and untracked files',
          \)
  endif
  return s:parser
endfunction " }}}

" Public
function! gita#features#add#action(statuses, option) abort " {{{
  let gita = gita#core#get()
  if !gita.is_enabled_with_warn()
    return
  endif
  let statuses = gita#utils#status#filter_statuses(
        \ a:statuses,
        \ a:option,
        \ s:get_validator(),
        \)
  if empty(a:statuses)
    return
  endif
  let args = ['add', '--'] + map(
        \ deepcopy(statuses),
        \ 'gita.git.get_absolute_path(v:val.path)'
        \)
  call gita.exec(args, a:option)
endfunction " }}}
function! gita#features#add#exec(...) abort " {{{
  let parser = s:get_parser()
  let opts = call(parser.parse, a:000, parser)
  let args = gita#utils#opts2args(opts)
  let files = get(opts, '__unknown__', [])
  let files = map(files, 'expand(v:val)')
  let statuses = gita#utils#status#get_statuses_of(files)
  call gita#features#add#run(statuses, {
        \ 'args': args,
        \})
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
