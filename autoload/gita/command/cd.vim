let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita cd',
          \ 'description': 'Change a current directory to the repository top',
          \})
  endif
  return s:parser
endfunction

function! gita#command#cd#execute(git, options) abort
  execute printf('cd %s', fnameescape(a:git.worktree))
  return a:git.worktree
endfunction

function! gita#command#cd#command(bang, range, args) abort
  let git = gita#core#get_or_fail()
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return {}
  endif
  let result = gita#command#cd#execute(git, options)
  return result
endfunction

function! gita#command#cd#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

