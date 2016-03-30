function! s:startup() abort
  let V = vital#of('gita')
  let P = V.import('System.Filepath')
  let R = V.import('Process')

  let g:gita#test = 1
  let g:gita#test#root = fnamemodify(resolve(getcwd()), ':p')

  " Create directories for test
  let temproot = fnamemodify(resolve(tempname()), ':p')
  let g:gita#test#inside  = P.join(temproot, 'inside')
  let g:gita#test#outside = P.join(temproot, 'outside')

  call mkdir(P.realpath(P.join(g:gita#test#inside, 'foo/bar')), 'p')
  call mkdir(P.realpath(P.join(g:gita#test#outside, 'foo/bar')), 'p')

  call writefile(['foo'], P.realpath(P.join(g:gita#test#inside, 'foo/bar/hoge.txt')))
  call writefile(['foo'], P.realpath(P.join(g:gita#test#outside, 'foo/bar/hoge.txt')))

  " Make a git repository
  call R.system(printf('git init %s', g:gita#test#inside))
endfunction

function! s:workon_root() abort
  silent execute printf('cd %s', fnameescape(g:gita#test#root))
endfunction

function! s:workon_inside() abort
  silent execute printf('cd %s', fnameescape(g:gita#test#inside))
endfunction

function! s:workon_outside() abort
  silent execute printf('cd %s', fnameescape(g:gita#test#outside))
endfunction

function! s:init() abort " {{{
  windo bwipeout!
  enew!
  for key in keys(w:)
    silent! unlet w:[key]
  endfor
  call s:workon_root()
endfunction " }}}

command! Init          call s:init()
command! WorkonRoot    call s:workon_root()
command! WorkonInside  call s:workon_inside()
command! WorkonOutside call s:workon_outside()

call s:startup()
