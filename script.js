const properties = [
  {
    id: 'shoreditch-loft',
    title: 'Loft creativo en Shoreditch',
    area: 'Shoreditch',
    price: 2450,
    beds: 1,
    baths: 1,
    size: 54,
    status: 'available',
    tags: ['Amoblado', 'Pet friendly', 'Cerca al Overground'],
    image: 'https://images.unsplash.com/photo-1527030280862-64139fba04ca?auto=format&fit=crop&w=1200&q=80',
  },
  {
    id: 'canary-wharf',
    title: 'Apartamento con vista al río',
    area: 'Canary Wharf',
    price: 3150,
    beds: 2,
    baths: 2,
    size: 78,
    status: 'available',
    tags: ['Gimnasio', 'Coworking', 'Thames Clipper'],
    image: 'https://images.unsplash.com/photo-1502672023488-70e25813eb80?auto=format&fit=crop&w=1200&q=80',
  },
  {
    id: 'notting-hill',
    title: 'Casa adosada en Notting Hill',
    area: 'Notting Hill',
    price: 4250,
    beds: 3,
    baths: 2,
    size: 112,
    status: 'soon',
    tags: ['Terraza', 'Calles tranquilas', 'Mercado local'],
    image: 'https://images.unsplash.com/photo-1484156818044-c040038b0710?auto=format&fit=crop&w=1200&q=80',
  },
  {
    id: 'greenwich-park',
    title: 'Ático frente al parque',
    area: 'Greenwich',
    price: 2750,
    beds: 2,
    baths: 2,
    size: 86,
    status: 'available',
    tags: ['Vista al parque', 'Balcones dobles', 'DLR & Elizabeth'],
    image: 'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=1200&q=80',
  },
  {
    id: 'kings-cross',
    title: 'Estudio moderno en King’s Cross',
    area: 'King’s Cross',
    price: 1900,
    beds: 0,
    baths: 1,
    size: 38,
    status: 'available',
    tags: ['Facturas incluidas', 'Zona tech', 'St Pancras Intl.'],
    image: 'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?auto=format&fit=crop&w=1200&q=80',
  },
  {
    id: 'southwark-warehouse',
    title: 'Warehouse con ladrillo visto',
    area: 'Southwark',
    price: 3350,
    beds: 2,
    baths: 1,
    size: 92,
    status: 'soon',
    tags: ['Open plan', 'Metro Jubilee', 'Cafés y galerías'],
    image: 'https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?auto=format&fit=crop&w=1200&q=80',
  },
];

const listEl = document.getElementById('properties');
const summaryEl = document.getElementById('results-summary');
const formEl = document.getElementById('filters');
const queryInput = document.getElementById('query');
const priceInput = document.getElementById('price');
const bedroomsSelect = document.getElementById('bedrooms');

function formatPrice(value) {
  return new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP', maximumFractionDigits: 0 }).format(value);
}

function availabilityLabel(status) {
  return status === 'available' ? 'Disponible' : 'Próximo mes';
}

function renderProperties(items) {
  listEl.innerHTML = '';

  if (!items.length) {
    listEl.innerHTML = `<p class="muted">Sin resultados. Ajusta los filtros o prueba con otra zona.</p>`;
    return;
  }

  const fragment = document.createDocumentFragment();

  items.forEach((property) => {
    const card = document.createElement('article');
    card.className = 'card';
    card.innerHTML = `
      <img class="card__image" src="${property.image}" alt="${property.title}">
      <div class="card__body">
        <div class="card__meta">
          <div>
            <h3>${property.title}</h3>
            <p class="muted">${property.area}</p>
          </div>
          <div class="availability ${property.status === 'soon' ? 'availability--soon' : ''}">
            ${availabilityLabel(property.status)}
          </div>
        </div>
        <div class="price">${formatPrice(property.price)} / mes</div>
        <div class="stats">
          <span>${property.beds === 0 || property.beds == null ? 'Estudio' : `${property.beds} hab.`}</span>
          <span>${property.baths} baños</span>
          <span>${property.size} m²</span>
        </div>
        <div class="tags">
          ${property.tags.map((tag) => `<span class="tag">${tag}</span>`).join('')}
        </div>
      </div>
    `;
    fragment.appendChild(card);
  });

  listEl.appendChild(fragment);
}

function applyFilters(event) {
  if (event) {
    event.preventDefault();
  }

  const term = queryInput.value.trim().toLowerCase();
  const maxPrice = Number(priceInput.value) || Infinity;
  const minBeds = bedroomsSelect.value === 'any' ? -1 : Number(bedroomsSelect.value);

  const filtered = properties.filter((property) => {
    const matchesTerm =
      term.length === 0 ||
      property.title.toLowerCase().includes(term) ||
      property.area.toLowerCase().includes(term) ||
      property.tags.some((tag) => tag.toLowerCase().includes(term));

    const matchesPrice = property.price <= maxPrice;
    const matchesBeds = minBeds === -1 || property.beds >= minBeds;

    return matchesTerm && matchesPrice && matchesBeds;
  });

  summaryEl.textContent = `${filtered.length} resultado${filtered.length === 1 ? '' : 's'} disponible${filtered.length === 1 ? '' : 's'}`;
  renderProperties(filtered);
}

formEl.addEventListener('submit', applyFilters);
formEl.addEventListener('input', () => applyFilters());

applyFilters();
