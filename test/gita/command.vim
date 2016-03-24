Describe gita#command
  Describe #execute({git}, {args}, {options})
    It executes a {args}
      let content = gita#command#execute(
            \ gita#core#get(), [
            \ 'rev-parse', '--is-inside-work-tree'
            \])
      Assert Equals(content, ['true'])
    End
  End
End

