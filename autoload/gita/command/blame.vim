let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita blame',
          \ 'description': 'Show what revision and author last modified each line of a file',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'a line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ '--ignore-whitespace', '-w',
          \ 'ignore whitespace when comparing.', {
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to blame.',
          \   'If nothing is specified, it show a blame of HEAD.',
          \   'If <commit> is specified, it show a blame of the named <commit>.',
          \ ], {
          \   'complete': function('gita#util#complete#commitish'),
          \ })
    call s:parser.add_argument(
          \ 'filename', [
          \   'A filename which you want to blame.',
          \   'If nothing is specified, the current buffer will be used.',
          \ ], {
          \   'complete': function('gita#util#complete#filename'),
          \ })
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'ignore-whitespace')
        let a:options.w = 1
        unlet a:options['ignore-whitespace']
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction

function! gita#command#blame#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#blame#default_options),
        \ options
        \)
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_filename(options)
  call gita#util#option#assign_selection(options)
  call gita#content#blame#open(options)
endfunction

function! gita#command#blame#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#blame', {
      \ 'default_options': {},
      \})
