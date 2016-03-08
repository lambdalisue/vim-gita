let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:String = s:V.import('Data.String')
let s:DateTime = s:V.import('DateTime')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:ProgressBar = s:V.import('ProgressBar')
let s:Prompt = s:V.import('Vim.Prompt')

function! s:get_candidate(index) abort
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  let lineinfo = get(blamemeta.lineinfos, a:index, {})
  if empty(lineinfo)
    return {}
  endif
  return deepcopy(blamemeta.chunks[lineinfo.chunkref])
endfunction

function! s:call_pseudo_command(...) abort
  let ret = s:Prompt.input('None', ':', get(a:000, 0, ''))
  redraw | echo
  if ret =~# '\v^[0-9]+$'
    call gita#command#ui#blame#select([ret])
  elseif ret =~# '^q\%(\|u\|ui\|uit\)!\?$' || ret =~# '^clo\%(\|s\|se\)!\?$'
    try
      let blameobj = gita#command#blame#get_blameobj_or_fail()
      let winnum_partner = gita#meta#get('content_type') ==# 'blame-navi'
            \ ? winbufnr(blameobj.view_bufnum)
            \ : winbufnr(blameobj.navi_bufnum)
      if winnum_partner != -1
        execute printf('%d%s', winnum_partner, ret)
      endif
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      call gita#util#handle_exception()
    endtry
    execute ret
  else
    execute ret
  endif
endfunction

function! gita#command#ui#blame#get_pseudo_linenum(linenum) abort
  " actual -> pseudo
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  let lineinfos = blamemeta.lineinfos
  if a:linenum > len(lineinfos)
    let lineinfo = lineinfos[-1]
  elseif a:linenum <= 0
    let lineinfo = lineinfos[0]
  else
    let lineinfo = lineinfos[a:linenum - 1]
  endif
  return lineinfo.linenum.final
endfunction

function! gita#command#ui#blame#get_actual_linenum(linenum) abort
  " pseudo -> actual
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  let linerefs = blamemeta.linerefs
  if a:linenum > len(linerefs)
    return linerefs[-1]
  elseif a:linenum <= 0
    return linerefs[0]
  else
    return linerefs[a:linenum-1]
  endif
endfunction

function! gita#command#ui#blame#select(selection) abort
  " pseudo -> actual
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  let actual_selection = [
        \ gita#command#ui#blame#get_actual_linenum(line_start),
        \ gita#command#ui#blame#get_actual_linenum(line_end),
        \]
  call gita#util#select(actual_selection)
endfunction

function! gita#command#ui#blame#set_pseudo_separators(separators, ...) abort
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  for linenum in a:separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

function! gita#command#ui#blame#define_actions() abort
  let action = gita#action#define(function('s:get_candidate'))
  function! action.actions.blame_command(candidates, ...) abort
    call s:call_pseudo_command()
  endfunction
  function! action.actions.blame_echo(candidates, ...) abort
    let candidate = get(a:candidates, 0, {})
    if empty(candidate)
      return
    endif
    let commit   = gita#meta#get('commit')
    let filename = gita#meta#get('filename')
    echo '=== Current ==='
    echo 'Commit:   ' . commit
    echo 'Filename: ' . filename
    echo '===  Chunk  ==='
    echo 'Summary:  ' . candidate.summary
    echo 'Author:   ' . candidate.author
    echo 'Boundary: ' . (get(candidate, 'boundary') ? 'boundary' : '')
    echo 'Commit:   ' . candidate.revision
    echo 'Previous: ' . get(candidate, 'previous', '')
    echo 'Filename: ' . candidate.filename
    echo 'Line (O): ' . candidate.linenum.original
    echo 'Line (F): ' . candidate.linenum.final
  endfunction
  function! action.actions.blame_enter(candidates, ...) abort
    let candidate = get(a:candidates, 0, {})
    if empty(candidate)
      return
    endif
    let commit = gita#meta#get('commit')
    if candidate.revision ==# commit
      if !has_key(candidate, 'previous')
        call gita#throw(
              \ 'Cancel:',
              \ printf('A commit %s has no previous commit', candidate.revision),
              \)
      endif
      let [revision, filename] = split(candidate.previous)
      if revision ==# commit
        call gita#throw(
              \ 'Cancel:',
              \ printf('A commit %s is a boundary commit', candidate.revision),
              \)
      endif
    else
      let revision = candidate.revision
      let filename = candidate.filename
    endif
    let linenum = gita#command#blame#get_pseudo_linenum(line('.'))
    let linenum = candidate.linenum.original + (linenum - candidate.linenum.final)
    let winnum = winnr()
    redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
    call gita#command#blame#open({
          \ 'backward': join([
          \   commit,
          \   gita#meta#get('filename'),
          \ ], ':'),
          \ 'commit': revision,
          \ 'filename': filename,
          \ 'selection': [linenum],
          \})
    execute printf('%dwincmd w', winnum)
    redraw | echo
  endfunction
  function! action.actions.blame_backward(candidates, ...) abort
    let backward = gita#meta#get('backward')
    if empty(backward)
      call gita#throw(
            \ 'Cancel:',
            \ 'No backward blame found',
            \)
    endif
    let [revision, filename] = split(backward, ':', 1)
    let winnum = winnr()
    redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
    call gita#command#blame#open({
          \ 'commit': revision,
          \ 'filename': filename,
          \ 'selection': [
          \   gita#command#blame#get_pseudo_linenum(line('.')),
          \ ],
          \})
    execute printf('%dwincmd w', winnum)
    redraw | echo
  endfunction

  nnoremap <silent><buffer> <Plug>(gita-blame-command)
        \ :<C-u>call gita#action#call('blame_command')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-echo)
        \ :<C-u>call gita#action#call('blame_echo')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-enter)
        \ :<C-u>call gita#action#call('blame_enter')<CR>
  nnoremap <silent><buffer> <Plug>(gita-blame-backward)
        \ :<C-u>call gita#action#call('blame_backward')<CR>

  nmap <buffer> : <Plug>(gita-blame-command)

  return action
endfunction


function! gita#command#blame#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \ 'backward': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#default_opener
        \ : options.opener
  let result = gita#command#blame#call(options)
  if options.anchor
    call gita#util#anchor#focus()
  endif
  " NOTE:
  " In case, do not call autocmd to prevent infinity-loop while both buffers
  " define BufReadCmd when these are already constructed.
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore=BufReadCmd
    call gita#command#blame#view#_open(
          \ result.blameobj, {
          \   'opener': opener,
          \   'commit': result.commit,
          \   'filename': result.filename,
          \   'backward': options.backward,
          \})
    call gita#command#blame#navi#_open(
          \ result.blameobj, {
          \   'opener': g:gita#command#blame#navi#default_opener,
          \   'commit': result.commit,
          \   'filename': result.filename,
          \   'backward': options.backward,
          \})
  finally
    call guard.restore()
  endtry
  " NOTE:
  " Order of appearance, navi#_edit -> view#_edit, is ciritical requirement.
  call gita#command#blame#navi#_edit()
  setlocal noscrollbind
  call gita#command#blame#select(options.selection)
  normal! z.
  wincmd p
  call gita#command#blame#view#_edit()
  setlocal noscrollbind
  call gita#command#blame#select(options.selection)
  normal! z.
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  wincmd p
  setlocal scrollbind
  setlocal cursorbind
  syncbind
  " focus gita-blame-navi
  wincmd p
endfunction

highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
highlight GitaPseudoSeparatorDefault term=underline cterm=underline ctermfg=8 gui=underline guifg=#363636
if !exists('s:_sign_defined')
  sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
  let s:_sign_defined = 1
endif

call gita#util#define_variables('command#ui#blame', {
      \ 'default_opener': 'tabnew',
      \})
