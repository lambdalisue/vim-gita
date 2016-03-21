let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! s:define_highlights() abort
  highlight GitaPseudoSeparatorDefault term=underline cterm=underline ctermfg=242 gui=underline guifg=#363636
  highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
  sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
  sign define GitaPseudoEmptySign
endfunction

function! s:call_pseudo_command() abort range
  let prefix = a:firstline == a:lastline ? '' : "'<,'>"
  let ret = s:Prompt.input('None', ':', prefix)
  redraw | echo
  if ret =~# '\v^[0-9]+$'
    let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
    call gita#ui#blame#select(blamemeta, [str2nr(ret)])
  else
    try
      execute ret
    catch /^Vim.\{-}:/
      call s:Prompt.error(substitute(v:exception, '^Vim.\{-}:', '', ''))
    endtry
  endif
endfunction

function! s:get_candidate(index) abort
  let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
  let lineinfo = get(blamemeta.lineinfos, a:index, {})
  if empty(lineinfo)
    return {}
  endif
  return blamemeta.chunks[lineinfo.chunkref]
endfunction

function! s:action_echo(candidate, options) abort
  echo string(a:candidate)
endfunction

function! s:action_enter(candidate, options) abort
  let commit = gita#meta#get_for('^blame-\%(navi\|view\)$', 'commit')
  if a:candidate.revision ==# commit
    if !has_key(a:candidate, 'previous')
      call gita#throw(
            \ 'Cancel:',
            \ printf('A commit %s has no previous commit', a:candidate.revision),
            \)
    endif
    let [revision, filename] = split(a:candidate.previous)
    if revision ==# commit
      call gita#throw(
            \ 'Cancel:',
            \ printf('A commit %s is a boundary commit', a:candidate.revision),
            \)
    endif
  else
    let revision = a:candidate.revision
    let filename = a:candidate.filename
  endif
  let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
  let linenum = gita#ui#blame#get_pseudo_linenum(blamemeta, line('.'))
  let linenum_next = a:candidate.linenum.original + (linenum - a:candidate.linenum.final)
  let winnum = winnr()
  redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
  call gita#ui#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': [linenum_next],
        \ 'previous': [
        \   commit,
        \   gita#meta#get_for('^blame-\%(navi\|view\)$', 'filename'),
        \   [linenum],
        \ ],
        \})
  execute printf('%dwincmd w', winnum)
  redraw | echo
endfunction

function! s:action_back(candidate, options) abort
  let previous = gita#meta#get_for('^blame-\%(navi\|view\)$', 'previous')
  if empty(previous)
    call gita#throw(
          \ 'Cancel:',
          \ 'No previous blame found',
          \)
  endif
  let [revision, filename, selection] = previous
  let winnum = winnr()
  redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
  call gita#ui#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': selection,
        \})
  execute printf('%dwincmd w', winnum)
  redraw | echo
endfunction

function! s:action_previous_chunk(candidate, options) abort
  let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
  let chunks = blamemeta.chunks
  if a:candidate.index <= 0
    call s:Prompt.warn('This is a first chunk')
    return
  endif
  let prev_chunk = chunks[a:candidate.index - 1]
  call gita#ui#blame#select(blamemeta, [prev_chunk.linenum.final])
endfunction

function! s:action_next_chunk(candidate, options) abort
  let blamemeta = gita#meta#get_for('^blame-\%(navi\|view\)$', 'blamemeta')
  let chunks = blamemeta.chunks
  if a:candidate.index >= len(chunks) - 1
    call s:Prompt.warn('This is a last chunk')
    return
  endif
  let next_chunk = chunks[a:candidate.index + 1]
  call gita#ui#blame#select(blamemeta, [next_chunk.linenum.final])
endfunction


function! gita#ui#blame#define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#define('blame:echo', function('s:action_echo'), {
        \ 'description': 'Echo a chunk',
        \ 'mapping_mode': 'n',
        \ 'requirements': [],
        \ 'options': {},
        \})
  call gita#action#define('blame:enter', function('s:action_enter'), {
        \ 'description': 'Enter in a commit of the chunk',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['revision', 'filename', 'linenum'],
        \ 'options': {},
        \})
  call gita#action#define('blame:back', function('s:action_back'), {
        \ 'description': 'Enter back in the previous revision',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['revision', 'filename', 'linenum'],
        \ 'options': {},
        \})
  call gita#action#define('blame:previous:chunk', function('s:action_previous_chunk'), {
        \ 'description': 'Move to the previous chunk',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['index'],
        \ 'options': {},
        \})
  call gita#action#define('blame:next:chunk', function('s:action_next_chunk'), {
        \ 'description': 'Move to the next chunk',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['index'],
        \ 'options': {},
        \})

  nmap <silent><buffer> : :<C-u>call <SID>call_pseudo_command()<CR>
  vmap <silent><buffer> : :call <SID>call_pseudo_command()<CR>
endfunction

function! gita#ui#blame#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'navigator_width': 50,
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#ui#blame#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('blame-navi', options)
  call gita#util#buffer#open(gita#ui#blame_navi#bufname(options), {
        \ 'opener': opener,
        \ 'window': 'blame_navi',
        \})
  set scrollbind
  silent syncbind
  " NOTE:
  " blame_view automatically opened from blame_navi
endfunction

function! gita#ui#blame#select(blamemeta, selection) abort
  " pseudo -> actual
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  let actual_selection = [
        \ gita#ui#blame#get_actual_linenum(a:blamemeta, line_start),
        \ gita#ui#blame#get_actual_linenum(a:blamemeta, line_end),
        \]
  call gita#util#select(actual_selection)
endfunction

function! gita#ui#blame#get_pseudo_linenum(blamemeta, linenum) abort
  " actual -> pseudo
  let lineinfos = a:blamemeta.lineinfos
  if a:linenum > len(lineinfos)
    let lineinfo = lineinfos[-1]
  elseif a:linenum <= 0
    let lineinfo = lineinfos[0]
  else
    let lineinfo = lineinfos[a:linenum - 1]
  endif
  return lineinfo.linenum.final
endfunction

function! gita#ui#blame#get_actual_linenum(blamemeta, linenum) abort
  " pseudo -> actual
  let linerefs = a:blamemeta.linerefs
  if a:linenum > len(linerefs)
    return linerefs[-1]
  elseif a:linenum <= 0
    return linerefs[0]
  else
    return linerefs[a:linenum-1]
  endif
endfunction

function! gita#ui#blame#set_pseudo_separators(blamemeta) abort
  let bufnum = bufnr('%')
  execute printf('sign unplace * buffer=%d', bufnum)
  execute printf(
        \ 'sign place 1 line=1 name=GitaPseudoEmptySign buffer=%d',
        \ bufnum,
        \)
  for linenum in a:blamemeta.separators
    execute printf(
          \ 'sign place %d line=%d name=GitaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, bufnum,
          \)
  endfor
endfunction

augroup vim_gita_internal_blame
  autocmd! *
  autocmd ColorScheme * call s:define_highlights()
augroup END
call s:define_highlights()

call gita#util#define_variables('ui#blame', {
      \ 'default_opener': 'tabedit',
      \})

