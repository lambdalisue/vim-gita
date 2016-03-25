let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')

function! s:action(candidate, options) abort
  let options = extend({
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_opener(options)
  call gita#option#assign_selection(options)

  let commit = get(a:candidate, 'commit', get(options, 'commit', ''))
  let opener = empty(options.opener) ? 'tabedit' : options.opener
  let selection = get(a:candidate, 'selection', options.selection)

  if s:BufferAnchor.is_available(opener)
    call s:BufferAnchor.focus()
  endif
  call gita#content#blame#open({
        \ 'commit': commit,
        \ 'filename': a:candidate.path,
        \ 'opener': opener,
        \ 'selection': selection,
        \})
endfunction

function! s:action_enter(candidate, options) abort
  let commit = gita#meta#get_for('^blame-', 'commit')
  let blamemeta = gita#meta#get_for('^blame-', 'blamemeta')

  if a:candidate.revision ==# commit
    if !has_key(a:candidate, 'previous')
      call gita#throw(printf(
            \ 'Cancel: A commit %s has no previous commit',
            \  a:candidate.revision,
            \))
    endif
    let [revision, filename] = matchlist(
          \ a:candidate.previous,
          \ '^\([^ ]\+\) \(.*\)$',
          \)[1 : 2]
    if revision ==# commit
      call gita#throw(printf(
            \ 'Cancel: A commit %s is a boundary commit',
            \ a:candidate.revision,
            \))
    endif
  else
    let revision = a:candidate.revision
    let filename = a:candidate.filename
  endif

  let linenum = gita#content#blame#get_pseudo_linenum(blamemeta, line('.'))
  let linenum_next = a:candidate.linenum.original + (linenum - a:candidate.linenum.final)
  redraw
  echo printf('Opening a blame content of "%s" in "%s"', filename, revision)
  call gita#content#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': [linenum_next],
        \ 'previous': [
        \   commit,
        \   gita#meta#expand('%'),
        \   [linenum],
        \ ],
        \})
endfunction

function! s:action_back(candidate, options) abort
  let previous = gita#meta#get_for('^blame-', 'previous')
  if empty(previous)
    call gita#throw('Cancel: No previous blame found')
  endif
  let [revision, filename, selection] = previous
  redraw
  echo printf('Opening a blame content of "%s" in %s', filename, revision)
  call gita#content#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': selection,
        \})
endfunction

function! s:action_previous_chunk(candidate, options) abort
  let blamemeta = gita#meta#get_for('^blame-', 'blamemeta')
  let chunks = blamemeta.chunks
  if a:candidate.index <= 0
    call s:Prompt.warn('This is a first chunk')
    return
  endif
  let prev_chunk = chunks[a:candidate.index - 1]
  call gita#content#blame#select(blamemeta, [prev_chunk.linenum.final])
endfunction

function! s:action_next_chunk(candidate, options) abort
  let blamemeta = gita#meta#get_for('^blame-', 'blamemeta')
  let chunks = blamemeta.chunks
  if a:candidate.index >= len(chunks) - 1
    call s:Prompt.warn('This is a last chunk')
    return
  endif
  let next_chunk = chunks[a:candidate.index + 1]
  call gita#content#blame#select(blamemeta, [next_chunk.linenum.final])
endfunction

function! s:call_pseudo_command() abort range
  let prefix = a:firstline == a:lastline ? '' : "'<,'>"
  let ret = s:Prompt.input('None', ':', prefix)
  redraw | echo
  if ret =~# '\v^[0-9]+$'
    let blamemeta = gita#meta#get_for('^blame-', 'blamemeta')
    call gita#content#blame#select(blamemeta, [str2nr(ret)])
  else
    try
      execute ret
    catch /^Vim.\{-}:/
      call s:Prompt.error(substitute(v:exception, '^Vim.\{-}:', '', ''))
    endtry
  endif
endfunction

function! gita#action#blame#define(disable_mappings) abort
  let is_blame_buffer = gita#meta#get('content_type') =~# '^blame-'
  if is_blame_buffer
    nnoremap <silent><buffer> : :<C-u>call <SID>call_pseudo_command()<CR>
    vnoremap <silent><buffer> : :call <SID>call_pseudo_command()<CR>
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
    call gita#action#define('blame:chunk:previous', function('s:action_previous_chunk'), {
          \ 'description': 'Move to the previous chunk',
          \ 'mapping_mode': 'n',
          \ 'requirements': ['index'],
          \ 'options': {},
          \})
    call gita#action#define('blame:chunk:next', function('s:action_next_chunk'), {
          \ 'description': 'Move to the next chunk',
          \ 'mapping_mode': 'n',
          \ 'requirements': ['index'],
          \ 'options': {},
          \})
  else
    call gita#action#define('blame', function('s:action'), {
          \ 'description': 'Blame a content',
          \ 'mapping_mode': 'n',
          \ 'requirements': ['path'],
          \ 'options': {},
          \})
  endif
  if a:disable_mappings
    return
  endif
  if is_blame_buffer
    nmap <buffer><nowait> [c <Plug>(gita-blame-chunk-previous)
    nmap <buffer><nowait> ]c <Plug>(gita-blame-chunk-next)
    nmap <buffer><nowait> <Return> <Plug>(gita-blame-enter)
    nmap <buffer><nowait> <Backspace> <Plug>(gita-blame-back)
  else
    nmap <buffer><nowait><expr> BB gita#action#smart_map('BB', '<Plug>(gita-blame)')
  endif
endfunction
