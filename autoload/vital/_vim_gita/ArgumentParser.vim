"******************************************************************************
" High functional argument (option) parser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort
  let s:P = a:V.import('Prelude')
  let s:D = a:V.import('Data.Dict')
  let s:L = a:V.import('Data.List')
  let s:C = a:V.import('ArgumentParser.Completer')

  let s:const = {}
  let s:const.types = {}
  let s:const.types.any = 0
  let s:const.types.value = 1
  let s:const.types.switch = 2
  let s:const.types.choice = 3
  lockvar s:const

  call extend(self, s:const)
endfunction
function! s:_vital_depends() abort
  return ['Prelude', 'Data.Dict', 'Data.List', 'ArgumentParser.Completer']
endfunction

function! s:splitargs(str) abort " {{{
  let single_quote = '\v''\zs[^'']+\ze'''
  let double_quote = '\v"\zs[^"]+\ze"'
  let bare_strings = '\v[^ \t''"]+'
  let pattern = printf('\v%%(%s|%s|%s)',
        \ single_quote,
        \ double_quote,
        \ bare_strings,
        \)
  return split(a:str, printf('\v%s*\zs%%(\s+|$)\ze', pattern))
endfunction " }}}
function! s:strip_quotes(str) abort " {{{
  if a:str =~# '\v^%(".*"|''.*'')$'
    return a:str[1:-2]
  else
    return a:str
  endif
endfunction " }}}
function! s:new(...) abort " {{{
  let options = extend({
        \ 'description': '',
        \}, get(a:000, 0, {}))
  let parser = extend(deepcopy(s:parser), s:D.pick(options, [
        \ 'description',
        \ 'enable_positional_assign',
        \]))
  return parser
endfunction " }}}

let s:parser = {
      \ 'hooks': {},
      \ 'arguments': {},
      \ 'positional': [],
      \ 'required': [],
      \ 'alias': {},
      \ 'validate_required': 1,
      \ 'validate_types': 1,
      \ 'validate_conflicts': 1,
      \ 'validate_superordinates': 1,
      \ 'validate_dependencies': 1,
      \ 'validate_pattern': 1,
      \}
function! s:parser._call_hook(name, opts) abort " {{{
  let opts = a:opts
  if has_key(self.hooks, a:name)
    let opts = call(self.hooks[a:name], [opts], self)
  endif
  return opts
endfunction " }}}
function! s:parser.add_argument(name, ...) abort " {{{
  " determind name
  if a:name =~# '^--\?'
    let positional = 0
    let name = substitute(a:name, '^--\?', '', '')
  else
    let positional = 1
    let name = a:name
  endif
  " determind arguments
  if a:0 == 0
    let description = ''
    let options = {}
  elseif a:0 == 1
    if s:P.is_string(a:1)
      let description = a:1
      let options = {}
    else
      let description = ''
      let options = a:1
    endif
  elseif a:0 == 2
    let description = a:1
    let options = a:2
  else
    throw 'vital: ArgumentParser: too much arguments are specified'
  endif
  let choices = get(options, 'choices', [])
  " create an argument instance
  let argument = extend({
        \ 'name': name,
        \ 'terminal': 0,
        \ 'positional': positional,
        \ 'required': 0,
        \ 'default': '',
        \ 'alias': '',
        \ 'type': -1,
        \ 'deniable': 0,
        \ 'choices': choices,
        \ 'pattern': '',
        \ 'conflicts': [],
        \ 'dependencies': [],
        \ 'superordinates': [],
        \}, options)
  " automatically assign argument type
  if argument.type == -1
    if !empty(argument.choices)
      let argument.type = s:const.types.choice
    elseif !empty(argument.pattern)
      let argument.type = s:const.types.value
    elseif argument.positional
      let argument.type = s:const.types.value
    else
      let argument.type = s:const.types.switch
    endif
  endif
  " validate options
  if positional && argument.alias
    throw 'vital: ArgumentParser: "alias" option cannot be specified to a positional argument'
  elseif positional && argument.alias
    throw 'vital: ArgumentParser: "default" option cannot be specified to a positional argument'
  elseif positional && argument.type != s:const.types.value && argument.type != s:const.types.choice
    throw 'vital: ArgumentParser: "type" option cannot be ANY or SWITCH for a positional argument'
  elseif positional && !empty(argument.conflicts)
    throw 'vital: ArgumentParser: "conflicts" option cannot be specified to a positional argument'
  elseif positional && !empty(argument.dependencies)
    throw 'vital: ArgumentParser: "dependencies" option cannot be specified to a positional argument'
  elseif positional && !empty(argument.superordinates)
    throw 'vital: ArgumentParser: "superordinates" option cannot be specified to a positional argument'
  elseif !empty(argument.default) && argument.required
    throw 'vital: ArgumentParser: "default" and "required" option cannot be specified together'
  elseif empty(argument.choices) && argument.type == s:const.types.choice
    throw 'vital: ArgumentParser: "type" is specified to "choice" but no "choices" is specified'
  elseif !empty(argument.pattern) && argument.type == s:const.types.switch
    throw 'vital: ArgumentParser: "pattern" option cannot be specified for SWITCH argument'
  endif
  " register argument
  let self.arguments[name] = argument
  " register positional
  if positional
    call add(self.positional, argument.name)
  endif
  " register required
  if argument.required
    call add(self.required, argument.name)
  endif
  " register alias
  if !empty(argument.alias)
    let self.alias[argument.alias] = argument.name
  endif
  " register completer
  if !has_key(argument, 'completer')
    if !empty(argument.choices)
      let argument.completer = s:C.new('choice', { 'choices': argument.choices })
    else
      let argument.completer = s:C.new('file')
    endif
  endif
  " return an argument instance for further manipulation
  return argument
endfunction " }}}
function! s:parser.get_conflicted_arguments(name, opts) abort " {{{
  let conflicts = self.arguments[a:name].conflicts
  if empty(conflicts)
    return []
  endif
  let conflicts_pattern = printf('\v^%%(%s)$', join(conflicts, '|'))
  return filter(keys(a:opts), 'v:val =~# conflicts_pattern')
endfunction " }}}
function! s:parser.get_superordinate_arguments(name, opts) abort " {{{
  let superordinates = self.arguments[a:name].superordinates
  if empty(superordinates)
    return []
  endif
  let superordinates_pattern = printf('\v^%%(%s)$', join(superordinates, '|'))
  return filter(keys(a:opts), 'v:val =~# superordinates_pattern')
endfunction " }}}
function! s:parser.get_missing_dependencies(name, opts) abort " {{{
  let dependencies = self.arguments[a:name].dependencies
  if empty(dependencies)
    return []
  endif
  let exists_pattern = printf('\v^%%(%s)$', join(keys(a:opts), '|'))
  return filter(dependencies, 'v:val !~# exists_pattern')
endfunction " }}}
function! s:parser.get_positional_arguments() abort " {{{
  return deepcopy(self.positional)
endfunction " }}}
function! s:parser.get_optional_arguments() abort " {{{
  return map(filter(values(self.arguments), '!v:val.positional'), 'v:val.name')
endfunction " }}}
function! s:parser.get_optional_argument_aliases() abort " {{{
  return keys(self.alias)
endfunction " }}}
function! s:parser.parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let opts = self.parse_cmdline(cmdline, extend({
        \ '__bang__': a:bang == '!',
        \ '__range__': a:range,
        \}, get(a:000, 1, {})))
  " assign default values
  let exists_pattern = printf('\v^%%(%s)$', join(keys(opts), '|'))
  for argument in values(self.arguments)
    if !empty(argument.default) && argument.name !~# exists_pattern
      let opts[argument.name] = argument.default
    endif
  endfor
  " validation
  let opts = self._call_hook('pre_validation', opts)
  if self.validate_required
    call self._validate_required(opts)
  endif
  if self.validate_types
    call self._validate_types(opts)
  endif
  if self.validate_conflicts
    call self._validate_conflicts(opts)
  endif
  if self.validate_superordinates
    call self._validate_superordinates(opts)
  endif
  if self.validate_dependencies
    call self._validate_dependencies(opts)
  endif
  if self.validate_pattern
    call self._validate_pattern(opts)
  endif
  let opts = self._call_hook('post_validation', opts)
  return opts
endfunction " }}}
function! s:parser.parse_cmdline(cmdline, ...) abort " {{{
  let args = s:splitargs(a:cmdline)
  return call(self.parse_args, [args] + a:000, self)
endfunction " }}}
function! s:parser.parse_args(args, ...) abort " {{{
  let opts = extend({
        \ '__unknown__': [],
        \ '__args__': [],
        \}, get(a:000, 0, {}))
  let opts.__args__ = extend(opts.__args__, a:args)
  let length = len(opts.__args__)
  let cursor = 0
  let arguments_pattern = printf('\v^%%(%s)$', join(keys(self.arguments), '|'))
  let positional_length = len(self.positional)
  let positional_cursor = 0
  while cursor < length
    let cword = opts.__args__[cursor]
    let nword = (cursor+1 < length) ? opts.__args__[cursor+1] : ''
    if cword =~# '^--\?'
      " optional argument
      let m = matchlist(cword, '\v^\-\-?([^=]+|)%(\=(.*)|)')
      let name = get(self.alias, m[1], m[1])
      if name =~# arguments_pattern
        if !empty(m[2])
          let value = s:strip_quotes(m[2])
        elseif get(self, 'enable_positional_assign', 0) && !empty(nword) && nword !~# '^--\?'
          let value = s:strip_quotes(nword)
          let cursor += 1
        else
          let value = 1
        endif
      elseif substitute(name, '^no-', '', '') =~# arguments_pattern
        let name = substitute(name, '^no-', '', '')
        if self.arguments[name].deniable
          let value = 0
        else
          call add(opts.__unknown__, cword)
          silent! unlet name
          silent! unlet value
        endif
      else
        call add(opts.__unknown__, cword)
        silent! unlet name
        silent! unlet value
      endif
    else
      if positional_cursor < positional_length
        let name = self.positional[positional_cursor]
        let value = s:strip_quotes(cword)
        let positional_cursor += 1
      else
        call add(opts.__unknown__, cword)
        silent! unlet name
        silent! unlet value
      endif
    endif
    if exists('name') && exists('value')
      let opts[name] = value
      " terminal check
      if self.arguments[name].terminal
        let cursor += 1
        break
      endif
    endif
    silent! unlet name
    silent! unlet value
    let cursor += 1
  endwhile
  " assign remaining args as unknown
  let opts.__unknown__ = extend(
        \ opts.__unknown__,
        \ opts.__args__[ cursor : ],
        \)
  return opts
endfunction " }}}
function! s:parser._validate_required(opts) abort " {{{
  let exists_pattern = printf('\v^%%(%s)$', join(keys(a:opts), '|'))
  for name in self.required
    if name !~# exists_pattern
      throw printf(
            \ 'vital: ArgumentParser: "%s" argument is required but not specified.',
            \ name,
            \)
    endif
  endfor
endfunction " }}}
function! s:parser._validate_types(opts) abort " {{{
  for [name, value] in items(a:opts)
    if name !~# '\v^__.*__$'
      let type = self.arguments[name].type
      if type == s:const.types.value && s:P.is_number(value)
        throw printf(
              \ 'vital: ArgumentParser: "%s" argument is VALUE argument but no value is specified.',
              \ name,
              \)
      elseif type == s:const.types.switch && s:P.is_string(value)
        throw printf(
              \ 'vital: ArgumentParser: "%s" argument is SWITCH argument but "%s" is specified.',
              \ name,
              \ value,
              \)
      elseif type == s:const.types.choice
        let pattern = printf('\v^%%(%s)$', join(self.arguments[name].choices, '|'))
        if s:P.is_number(value)
          throw printf(
                \ 'vital: ArgumentParser: "%s" argument is CHOICE argument but no value is specified.',
                \ name,
                \)
        elseif value !~# pattern
          throw printf(
                \ 'vital: ArgumentParser: "%s" argument is CHOICE argument but an invalid value "%s" is specified.',
                \ name,
                \ value,
                \)
        endif
      endif
    endif
    silent! unlet name
    silent! unlet value
  endfor
endfunction " }}}
function! s:parser._validate_conflicts(opts) abort " {{{
  for [name, value] in items(a:opts)
    if name !~# '\v^__.*__$'
      let conflicts = self.get_conflicted_arguments(name, a:opts)
      if !empty(conflicts)
        throw printf(
              \ 'vital: ArgumentParser: "%s" argument conflicts with "%s"',
              \ name,
              \ conflicts[0],
              \)
      endif
    endif
    silent! unlet name
    silent! unlet value
  endfor
endfunction " }}}
function! s:parser._validate_superordinates(opts) abort " {{{
  for [name, value] in items(a:opts)
    if name !~# '\v^__.*__$'
      let superordinates = self.get_superordinate_arguments(name, a:opts)
      if !empty(self.arguments[name].superordinates) && empty(superordinates)
        throw printf(
              \ 'vital: ArgumentParser: No superordinate argument of "%s" is specified',
              \ name,
              \)
      endif
    endif
    silent! unlet name
    silent! unlet value
  endfor
endfunction " }}}
function! s:parser._validate_dependencies(opts) abort " {{{
  for [name, value] in items(a:opts)
    if name !~# '\v^__.*__$'
      let dependencies = self.get_missing_dependencies(name, a:opts)
      if !empty(dependencies)
        throw printf(
              \ 'vital: ArgumentParser: "%s" argument is required for "%s" but missing',
              \ dependencies[0],
              \ name,
              \)
      endif
    endif
    silent! unlet name
    silent! unlet value
  endfor
endfunction " }}}
function! s:parser._validate_pattern(opts) abort " {{{
  for [name, value] in items(a:opts)
    if name !~# '\v^__.*__$'
      let pattern = self.arguments[name].pattern
      if !empty(pattern) && value !~# pattern
        throw printf(
              \ 'vital: ArgumentParser: A value of "%s" argument does not a specified pattern "%s".',
              \ name,
              \ pattern,
              \)
      endif
    endif
    silent! unlet name
    silent! unlet value
  endfor
endfunction " }}}
function! s:parser.complete(arglead, cmdline, cursorpos, opts) abort " {{{
  if a:arglead =~# '\v^\-\-?[^=]+\='
    return self._complete_optional_argument_value(
          \ a:arglead,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:opts,
          \)
  elseif a:arglead =~# '\v^\-\-?'
    return self._complete_optional_argument(
          \ a:arglead,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:opts,
          \)
  else
    return self._complete_positional_argument_value(
          \ a:arglead,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:opts,
          \)
  endif
endfunction " }}}
function! s:parser._complete_optional_argument_value(arglead, cmdline, cursorpos, opts) abort " {{{
  let m = matchlist(a:arglead, '\v^\-\-?([^=]+)\=(.*)')
  let name = m[1]
  let value = m[2]
  if has_key(self.arguments, name)
    let candidates = self.arguments[name].completer.complete(
          \ value,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:opts,
          \)
  else
    let candidates = []
  endif
  return candidates
endfunction " }}}
function! s:parser._complete_optional_argument(arglead, cmdline, cursorpos, opts) abort " {{{
  let candidates = []
  for argument in values(self.arguments)
    if has_key(a:opts, argument.name) || argument.positional
      continue
    elseif !empty(argument.conflicts) && !empty(self.get_conflicted_arguments(argument.name, a:opts))
      continue
    elseif !empty(argument.superordinates) && empty(self.get_superordinate_arguments(argument.name, a:opts))
      continue
    endif
    if '--' . argument.name =~# '^' . a:arglead
      call add(candidates, '--' . argument.name)
    endif
    if !empty(argument.alias) && '-' . argument.alias =~# '^' . a:arglead
      call add(candidates, '-' . argument.alias)
    endif
  endfor
  return candidates
endfunction " }}}
function! s:parser._complete_positional_argument_value(arglead, cmdline, cursorpos, opts) abort " {{{
  let candidates = []
  let npositional = 0
  for argument in values(self.arguments)
    if argument.positional && has_key(a:opts, argument.name)
      let npositional += 1
    endif
  endfor
  if len(a:arglead) > 0
    let npositional -= 1
  endif
  let cpositional = get(self.arguments, get(self.positional, npositional, -1), {})
  if !empty(cpositional)
    let candidates = cpositional.completer.complete(
          \ a:arglead,
          \ a:cmdline,
          \ a:cursorpos,
          \ a:opts,
          \)
  endif
  return candidates
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
