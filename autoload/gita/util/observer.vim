let s:V = gita#vital()
let s:BufferObserver = s:V.import('Vim.Buffer.Observer')


function! gita#util#observer#attach(...) abort
  call call(s:BufferObserver.attach, a:000, s:BufferObserver)
endfunction

function! gita#util#observer#update() abort
  call call(s:BufferObserver.update, a:000, s:BufferObserver)
endfunction

function! gita#util#observer#update_all() abort
  call call(s:BufferObserver.update_all, a:000, s:BufferObserver)
endfunction

" Automatically start observation when it's sourced
augroup vim_gita_internal_util_observer
  autocmd! *
  autocmd User GitaStatusModified nested call gita#util#observer#update_all()
augroup END
