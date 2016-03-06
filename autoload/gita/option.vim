let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! gita#option#cascade(content_type, options, ...) abort
  let options = get(a:000, 0, {})
  let options = extend(options, gita#get_meta_for(a:content_type, 'options', {}))
  let options = extend(options, a:options)
  return options
endfunction

function! gita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif

  let content_type = gita#get_meta('content_type')
  if content_type =~# '^\%(status\|commit\|ls\|diff-ls\)$'
    let candidate = get(gita#action#get_candidates(), 0, {})
    if has_key(candidate, 'commit')
      let a:options.commit = candidate.commit
    endif
  endif
  if empty(get(a:options, 'commit'))
    if !empty(gita#get_meta('commit'))
      let a:options.commit = gita#get_meta('commit')
    endif
  endif
endfunction

function! gita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  elseif len(get(a:options, '__unknown__')) > 0
    let a:options.filename = a:options.__unknown__[0]
  endif
  let content_type = gita#get_meta('content_type')
  if content_type =~# '^\%(status\|commit\|ls\|diff-ls\)$'
    let candidate = get(gita#action#get_candidates(), 0, {})
    if has_key(candidate, 'path')
      let a:options.filename = candidate.path
    endif
  endif
  if empty(get(a:options, 'filename'))
    if !empty(gita#get_meta('filename'))
      let a:options.filename = gita#get_meta('filename')
    elseif !empty(gita#expand('%'))
      " NOTE:
      " gita#expand() always return a real absolute path or ''
      let a:options.filename = gita#expand('%')
    endif
  endif
endfunction

function! gita#option#assign_selection(options) abort
  if has_key(a:options, 'selection')
    let a:options.selection = map(
          \ split(a:options.selection, '-'),
          \ 'str2nr(v:val)',
          \)
  else
    let a:options.selection = get(
          \ a:options,
          \ '__range__',
          \ mode() =~# '^\c\%(v\|CTRL-V\|s\)$'
          \   ? [line("'<"), line("'>")]
          \   : [line('.')],
          \)
  endif

  let content_type = gita#get_meta('content_type')
  if content_type =~# '^blame-\%(navi\|view\)$'
    let line_start = get(a:options.selection, 0, 0)
    let line_end = get(a:options.selection, 1, line_start)
    let a:options.selection = [
          \ gita#command#blame#get_pseudo_linenum(line_start),
          \ gita#command#blame#get_pseudo_linenum(line_end),
          \]
  elseif !empty(content_type)
    let a:options.selection = []
  endif
endfunction

function! gita#option#assign_opener(options, ...) abort
  if !empty(get(a:options, 'opener'))
    return
  endif

  let default_opener = get(a:000, 0, '')
  let default_opener = empty(default_opener)
        \ ? g:gita#option#default_opener
        \ : default_opener
  let content_type = gita#get_meta('content_type')
  if content_type =~# '^blame-\%(navi\|view\)$'
    let a:options['opener'] = 'tabedit'
  else
    let a:options['opener'] = default_opener
  endif
endfunction

call gita#util#define_variables('option', {
      \ 'default_opener': 'edit',
      \})
