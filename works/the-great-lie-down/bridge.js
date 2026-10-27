(function () {
  const manifestNode = document.getElementById('instant-author-template');
  const manifest = manifestNode ? JSON.parse(manifestNode.textContent || '{}') : { fields: [] };
  const defaults = Object.fromEntries((manifest.fields || []).map(field => [field.key, field.default]));
  const nodes = key => Array.from(document.querySelectorAll(`[data-instant-field="${key}"]`));

  function text(value, fallback, limit) {
    const result = String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
    return (result || fallback || '').slice(0, limit);
  }

  function authors(value) {
    const source = Array.isArray(value) ? value : String(value || '').split(/[,|]/);
    const result = source.map(value => text(value, '', 80)).filter(Boolean).slice(0, 24);
    return result.length ? result : [...(defaults.authors || ['Bob'])];
  }

  function formatAuthors(values) {
    if (values.length < 2) return values[0] || '';
    if (values.length === 2) return `${values[0]} & ${values[1]}`;
    return `${values.slice(0, -1).join(', ')} & ${values[values.length - 1]}`;
  }

  function apply(input) {
    const combinedDedication = text(input.dedication, '', 500);
    const edition = {
      authors: authors(input.authors),
      character_name: text(input.character_name, defaults.character_name, 60),
      dedication_to: combinedDedication ? '' : text(input.dedication_to, defaults.dedication_to, 100),
      dedication_message: combinedDedication || text(input.dedication_message, defaults.dedication_message, 500)
    };
    const credit = formatAuthors(edition.authors);
    nodes('authors').forEach(node => { node.textContent = credit; });
    nodes('character_name').forEach(node => { node.textContent = edition.character_name; });
    nodes('dedication_to').forEach(node => { node.textContent = edition.dedication_to; });
    nodes('dedication_message').forEach(node => { node.textContent = edition.dedication_message; });
    const authorNames = document.querySelector('.instant-author-names');
    if (authorNames) authorNames.replaceChildren(...edition.authors.map((name, index) => {
      const item = document.createElement('span'); item.textContent = name;
      if (index) item.dataset.separator = '◆'; return item;
    }));
    document.querySelectorAll('[data-instant-aria-template]').forEach(node => {
      node.setAttribute('aria-label', node.dataset.instantAriaTemplate.replace('{{authors}}', credit));
    });
  }

  window.addEventListener('message', event => {
    if (event.source !== window.parent || event.data?.type !== 'instant-author:apply-edition') return;
    apply(event.data.edition || defaults);
  });

  Array.from(document.querySelectorAll('body *')).forEach(node => {
    if (node.children.length === 0 && node.textContent.trim().toLowerCase() === 'by bob' && !node.closest('[data-instant-field="authors"]')) node.hidden = true;
  });
  const illustratedBookAuthor = document.querySelector('.hero-book__author');
  if (illustratedBookAuthor) illustratedBookAuthor.hidden = true;

  window.parent.postMessage({ type: 'instant-author:ready' }, '*');
})();
