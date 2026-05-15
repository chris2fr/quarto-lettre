local function inject(meta, filename, key)
  local f = io.open(filename, 'r')
  if not f then return end
  local content = f:read('*all')
  f:close()
  local fmt = FORMAT:match('html') and 'html' or FORMAT
  local rendered = pandoc.write(pandoc.read(content, 'markdown'), fmt):gsub('\n$', '')
  meta[key] = pandoc.MetaBlocks({ pandoc.RawBlock(fmt, rendered) })
end

function Meta(meta)
  inject(meta, '_header.qmd', 'page-header')
  inject(meta, '_footer.qmd', 'page-footer')
  return meta
end
