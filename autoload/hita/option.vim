let s:V = gita#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! gita#option#init(content_type, options, ...) abort
  let options = deepcopy(a:options)
  let content_type = gita#get_meta('content_type', '')
  if !empty(a:content_type)&& content_type =~# a:content_type
    call extend(options, gita#get_meta('options', {}), 'keep')
  endif
  call extend(options, get(a:000, 0, {}), 'keep')
  return options
endfunction

function! gita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif
  let commit = gita#get_meta('commit')
  if !empty(commit)
    let a:options.commit = commit
  endif
endfunction
function! gita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  " NOTE:
  " gita#expand() always return a real absolute path or ''
  let filename = gita#expand('%')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction
