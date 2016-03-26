try:
    import vim
except ImportError:
    raise ImportError(
        '"vim" is not available. This module require to be loaded from Vim.'
    )


#
# NOTE
#   Vim use a global namespace for python/python3 so define a unique name
#   function and write a code inside of the function to prevent conflicts.
#
def _vim_vital_Git_Parser_main():
    import sys
    import re
    NON_WORD = re.compile(r'\W')

    def parse_blame(content, callback=None):
        revisions = {}
        chunks = []
        current_revision = {}
        current_chunk = {}
        has_content = False
        chunk_index = -1
        for i, line in enumerate(content):
            if callback:
                callback(i)
            bits = NON_WORD.split(line)
            if len(bits[0]) == 40:
                if len(bits) < 4:
                    # nlines column does not exists, mean that this line is in
                    # a current chunk
                    continue
                revision = bits[0]
                headline = {
                    'revision': revision,
                    'linenum': {
                        'original': int(bits[1]),
                        'final': int(bits[2]),
                    },
                    'nlines': 0 if len(bits) < 3 else bits[3],
                }
                if revision not in revisions:
                    revisions[revision] = {}
                current_revision = revisions[revision]
                chunk_index += 1
                current_chunk = headline
                current_chunk['index'] = chunk_index
                current_chunk['contents'] = []
                chunks.append(current_chunk)
            elif len(bits[0]) == 0:
                has_content = True
                current_chunk['contents'].append(line[1:])  # remove leading \t
            elif line == 'boundary':
                current_revision['boundary'] = 1
            else:
                bits = line.split(' ')
                key = bits[0].replace('-', '_')
                val = ' '.join(bits[1:])
                current_revision[key] = val
        if not has_content:
            chunks = sorted(chunks, key=lambda x: x['linenum']['final'])
            index = 0
            for chunk in chunks:
                if 'content' in chunk:
                    del chunk['content']
                chunk['index'] = index
                index += 1
        return {
            'revisions': revisions,
            'chunks': chunks,
            'has_content': has_content,
        }

    def format_exception():
        exc_type, exc_obj, tb = sys.exc_info()
        f = tb.tb_frame
        lineno = tb.tb_lineno
        filename = f.f_code.co_filename
        return "%s: %s at %s:%d" % (
            exc_obj.__class__.__name__,
            exc_obj, filename, lineno,
        )

    def callback_vim(i):
        vim.command('call progressbar.update(%d)' % i)

    # Execute a main code
    namespace = {}
    try:
        kwargs = vim.eval('kwargs')
        if vim.eval('get(l:, \'progressbar\')'):
            kwargs['callback'] = callback_vim
        blameobj = parse_blame(**kwargs)
        namespace['blameobj'] = blameobj
    except:
        namespace['exception'] = format_exception()
    return namespace

# Call main code
_vim_vital_Git_Parser_response = _vim_vital_Git_Parser_main()
