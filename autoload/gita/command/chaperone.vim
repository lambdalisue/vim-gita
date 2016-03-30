let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita chaperone',
          \ 'description': 'Compare differences and help to solve conflictions (UI only)',
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
    "call s:parser.add_argument(
    "      \ '--one', '-1',
    "      \ 'open a chaperoneable diff buffer', {
    "      \   'conflicts': ['two', 'three'],
    "      \})
    call s:parser.add_argument(
          \ '--two', '-2',
          \ 'open a chaperoneable index and workspace buffers', {
          \   'conflicts': ['one', 'three'],
          \})
    call s:parser.add_argument(
          \ '--three', '-3',
          \ 'open a HEAD, chaperoneable index, and workspace buffers', {
          \   'conflicts': ['one', 'two'],
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'a filename going to be chaperoneed. if omited, the current buffer is used', {
          \   'complete': function('gita#util#complete#filename'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'one')
        let a:options.method = 'one'
      elseif get(a:options, 'two')
        let a:options.method = 'two'
      else
        let a:options.method = 'three'
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction

function! gita#command#chaperone#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#util#option#assign_filename(options)
  call gita#util#option#assign_selection(options)
  call gita#util#option#assign_opener(options)
  call gita#content#chaperone#open(options)
endfunction

function! gita#command#chaperone#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
