let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_opener(options)
  call gita#option#assign_selection(options)
  let options.selection = get(a:candidate, 'selection', options.selection)
  let options.opener = empty(options.opener) ? 'tabedit' : options.opener
  if options.anchor && gita#util#anchor#is_available(options.opener)
    call gita#util#anchor#focus()
  endif
  call gita#content#blame#open({
        \ 'commit': get(a:candidate, 'commit', get(options, 'commit', '')),
        \ 'filename': a:candidate.path,
        \ 'opener': options.opener,
        \ 'selection': options.selection,
        \})
endfunction

function! s:action_enter(candidate, options) abort
  let commit = gita#meta#get_for('^blame-', 'commit')
  if a:candidate.revision ==# commit
    if !has_key(a:candidate, 'previous')
      call gita#throw(join([
            \ 'Cancel:',
            \ printf('A commit %s has no previous commit', a:candidate.revision),
            \]))
    endif
    let [revision, filename] = split(a:candidate.previous)
    if revision ==# commit
      call gita#throw(join([
            \ 'Cancel:',
            \ printf('A commit %s is a boundary commit', a:candidate.revision),
            \]))
    endif
  else
    let revision = a:candidate.revision
    let filename = a:candidate.filename
  endif
  let blamemeta = gita#meta#get_for('^blame-', 'blamemeta')
  let linenum = gita#content#blame#get_pseudo_linenum(blamemeta, line('.'))
  let linenum_next = a:candidate.linenum.original + (linenum - a:candidate.linenum.final)
  let winnum = winnr()
  redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
  call gita#content#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': [linenum_next],
        \ 'previous': [
        \   commit,
        \   gita#meta#get_for('^blame-', 'filename'),
        \   [linenum],
        \ ],
        \})
  execute printf('%dwincmd w', winnum)
  redraw | echo
endfunction

function! s:action_back(candidate, options) abort
  let previous = gita#meta#get_for('^blame-', 'previous')
  if empty(previous)
    call gita#throw(join([
          \ 'Cancel:',
          \ 'No previous blame found',
          \]))
  endif
  let [revision, filename, selection] = previous
  let winnum = winnr()
  redraw | echo printf('Opening a blame content of "%s" in %s', filename, revision)
  call gita#content#blame#open({
        \ 'commit': revision,
        \ 'filename': filename,
        \ 'selection': selection,
        \})
  execute printf('%dwincmd w', winnum)
  redraw | echo
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
    nmap <silent><buffer> : :<C-u>call <SID>call_pseudo_command()<CR>
    vmap <silent><buffer> : :call <SID>call_pseudo_command()<CR>
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
  else
    nmap <buffer><nowait><expr> BB gita#action#smart_map('BB', '<Plug>(gita-blame)')
  endif
endfunction

call gita#util#define_variables('action#blame', {
      \ 'default_opener': '',
      \})
