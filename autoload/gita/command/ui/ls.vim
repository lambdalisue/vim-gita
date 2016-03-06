
function! s:on_BufReadCmd(options) abort
  let options = gita#option#cascade('^ls$', a:options, {
        \})
  let result = gita#command#ls#call(options)
  call gita#meta#set('content_type', 'ls')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('candidates', result.candidates)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_ls
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ls#redraw()
endfunction
