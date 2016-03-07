let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')

function! s:on_BufReadCmd(options) abort
  let blameobj = gita#command#blame#_get_blameobj_or_fail()
  if !has_key(blameobj, 'blamemeta') || gita#meta#get('winwidth') != winwidth(0)
    " Construct 'blamemeta' from 'blameobj'. It is time-consuming process.
    " Store constructed 'blamemeta' in 'blameobj' so that blame-view buffer
    " can access to the instance.
    let blameobj.blamemeta = gita#command#blame#format(blameobj, winwidth(0))
    call gita#meta#set('winwidth', winwidth(0))
  endif
  call s:define_actions()
  augroup vim_gita_internal_blame_navi
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call s:on_CursorMoved()
    autocmd BufReadCmd  <buffer> nested call s:on_BufReadCmd()
  augroup END
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber norelativenumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=gita-blame-navi
  call gita#command#ui#blame_navi#redraw()
endfunction
