let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

let s:registry = {}
function! gita#command#is_registered(name) abort
  return index(keys(s:registry), a:name) != -1
endfunction
function! gita#command#register(name, command, complete, ...) abort
  if has_key(s:registry, a:name)
    call gita#throw(printf(
          \ 'ValidationError: A command "%s" has already been registered',
          \ a:name,
          \))
  endif
  let s:registry[a:name] = {
        \ 'command': s:Prelude.is_string(a:command)
        \   ? function(a:command)
        \   : a:command,
        \ 'complete': s:Prelude.is_string(a:complete)
        \   ? function(a:complete)
        \   : a:complete,
        \}
endfunction
function! gita#command#unregister(name) abort
  if !has_key(s:registry, a:name)
    call gita#throw(printf(
          \ 'ValidationError: A command "%s" has not been registered yet',
          \ a:name,
          \))
  endif
  unlet s:registry[a:name]
endfunction

function! s:apply_command(name, options) abort
  let args = [a:name] + a:options.__unknown__
  let git = gita#get()
  if git.is_enabled
    let args = ['-C', git.worktree] + args
  endif
  let config = s:GitProcess.get_config()
  let args = [config.executable] + config.arguments + args
  execute printf('!%s', join(args))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita',
          \ 'description': [
          \   'A git manipulation command',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'An action name of vim-gita. The following actions are available:',
          \ ], {
          \   'required': 1,
          \   'terminal': 1,
          \   'complete': function('s:complete_action'),
          \})
    " TODO: Write available actions
  endif
  return s:parser
endfunction
function! s:complete_action(arglead, cmdline, cursorpos, ...) abort
  let available_commands = keys(s:registry)
  return filter(available_commands, 'v:val =~# "^" . a:arglead')
endfunction
function! gita#command#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if !empty(options)
    let bang  = a:1
    let range = a:2
    let args  = join(options.__unknown__)
    let name  = get(options, 'action', '')
    if bang !=# '!'  && gita#command#is_registered(name)
      try
        call s:registry[name].command(bang, range, args)
      catch /^\%(vital: Git[:.]\|vim-gita:\)/
        call gita#util#handle_exception()
      endtry
    else
      call s:apply_command(name, options)
      call gita#util#doautocmd('StatusModified')
    endif
  endif
endfunction
function! gita#command#complete(arglead, cmdline, cursorpos, ...) abort
  let bang    = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\C^Gita!\?\s', '', '')
  let cmdline = substitute(cmdline, '[^ ]\+$', '', '')
  let parser  = s:get_parser()
  let options = call(parser.parse, [bang, [0, 0], cmdline], parser)
  if !empty(options)
    let name = get(options, 'action', '')
    if gita#command#is_registered(name)
      try
        return s:registry[name].complete(a:arglead, cmdline, a:cursorpos)
      catch
        " fail silently
        call s:Prompt.debug(v:exception)
        call s:Prompt.debug(v:throwpoint)
        return []
      endtry
    endif
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

" Register sub commands
call gita#command#register('add',
      \ 'gita#command#add#command',
      \ 'gita#command#add#complete',
      \)
call gita#command#register('apply',
      \ 'gita#command#apply#command',
      \ 'gita#command#apply#complete',
      \)
call gita#command#register('blame',
      \ 'gita#command#blame#command',
      \ 'gita#command#blame#complete',
      \)
call gita#command#register('browse',
      \ 'gita#command#browse#command',
      \ 'gita#command#browse#complete',
      \)
call gita#command#register('commit',
      \ 'gita#command#commit#command',
      \ 'gita#command#commit#complete',
      \)
call gita#command#register('checkout',
      \ 'gita#command#checkout#command',
      \ 'gita#command#checkout#complete',
      \)
call gita#command#register('diff',
      \ 'gita#command#diff#command',
      \ 'gita#command#diff#complete',
      \)
call gita#command#register('reset',
      \ 'gita#command#reset#command',
      \ 'gita#command#reset#complete',
      \)
call gita#command#register('rm',
      \ 'gita#command#rm#command',
      \ 'gita#command#rm#complete',
      \)
call gita#command#register('show',
      \ 'gita#command#show#command',
      \ 'gita#command#show#complete',
      \)
call gita#command#register('status',
      \ 'gita#command#status#command',
      \ 'gita#command#status#complete',
      \)
