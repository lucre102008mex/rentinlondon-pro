/**
 * RentInLondon PRO — Dashboard Script
 * Connects to Supabase for real-time data.
 * Configure SUPABASE_URL and SUPABASE_ANON_KEY below.
 */

// ─── Configuration ──────────────────────────────────────────────────────────
const CONFIG = {
  // Replace with your actual Supabase credentials
  SUPABASE_URL: '',       // e.g. https://xxxxx.supabase.co
  SUPABASE_ANON_KEY: '',  // your anon key
  REFRESH_INTERVAL: 30000, // 30 seconds
};

// ─── Agent Definitions ──────────────────────────────────────────────────────
const AGENTS = [
  { id: 'alex',         name: 'Alex',         channel: 'Telegram', role: 'Coordinator / Reports',  type: 'main' },
  { id: 'ivy',          name: 'Ivy',          channel: 'WhatsApp', role: 'UK Intake / Nurturing',   type: 'main' },
  { id: 'rose',         name: 'Rose',         channel: 'WhatsApp', role: 'UK Ads Leads (CTWA)',     type: 'main' },
  { id: 'salo',         name: 'Salo',         channel: 'WhatsApp', role: 'UK Marketplace Leads',    type: 'main' },
  { id: 'jeanette',     name: 'Jeanette',     channel: 'WhatsApp', role: 'UK + Intl / Contracts',   type: 'main' },
  { id: 'ads-fb',       name: 'Ads-FB',       channel: 'Internal', role: 'Campaign Management',     type: 'sub' },
  { id: 'ads-gumtree',  name: 'Ads-Gumtree',  channel: 'Internal', role: 'Listings Management',     type: 'sub' },
  { id: 'script-runner', name: 'Script-Runner', channel: 'Internal', role: 'Data Tasks / Reactivation', type: 'sub' },
];

// ─── State ──────────────────────────────────────────────────────────────────
let agentStates = {};
AGENTS.forEach(a => { agentStates[a.id] = { active: true, leads: 0, tokensToday: 0 }; });

// ─── Clock ──────────────────────────────────────────────────────────────────
function updateClock() {
  const now = new Date();
  const londonTime = now.toLocaleTimeString('en-GB', { timeZone: 'Europe/London', hour: '2-digit', minute: '2-digit', second: '2-digit' });
  document.getElementById('currentTime').textContent = londonTime;
}
setInterval(updateClock, 1000);
updateClock();

// ─── Supabase Helpers ───────────────────────────────────────────────────────
async function supabaseQuery(path, options = {}) {
  if (!CONFIG.SUPABASE_URL || !CONFIG.SUPABASE_ANON_KEY) return null;

  const url = `${CONFIG.SUPABASE_URL}/rest/v1/${path}`;
  try {
    const response = await fetch(url, {
      headers: {
        'apikey': CONFIG.SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${CONFIG.SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': options.count ? 'count=exact' : '',
      },
    });
    if (!response.ok) throw new Error(`${response.status}`);
    const data = await response.json();
    const count = response.headers.get('content-range');
    return { data, count: count ? parseInt(count.split('/')[1]) : data.length };
  } catch (err) {
    console.error(`Supabase query failed: ${path}`, err);
    return null;
  }
}

// ─── Render Agents Grid ─────────────────────────────────────────────────────
function renderAgents() {
  const grid = document.getElementById('agentsGrid');
  grid.innerHTML = AGENTS.map(agent => {
    const state = agentStates[agent.id];
    const isActive = state.active;
    const statusClass = isActive ? 'agent-card__status--active' : 'agent-card__status--inactive';
    const statusText = isActive ? '● Active' : '● Inactive';
    const toggleLabel = isActive ? 'Kill' : 'Enable';
    const toggleClass = isActive ? 'btn--danger' : 'btn--success';

    return `
      <div class="agent-card" id="agent-${agent.id}">
        <div class="agent-card__header">
          <span class="agent-card__name">${agent.name}</span>
          <span class="agent-card__status ${statusClass}">${statusText}</span>
        </div>
        <div class="agent-card__meta">
          <div class="agent-card__meta-item">
            <span class="agent-card__meta-label">Channel</span>
            <span class="agent-card__meta-value">${agent.channel}</span>
          </div>
          <div class="agent-card__meta-item">
            <span class="agent-card__meta-label">Role</span>
            <span class="agent-card__meta-value">${agent.role}</span>
          </div>
          <div class="agent-card__meta-item">
            <span class="agent-card__meta-label">Assigned Leads</span>
            <span class="agent-card__meta-value">${state.leads}</span>
          </div>
          <div class="agent-card__meta-item">
            <span class="agent-card__meta-label">Tokens Today</span>
            <span class="agent-card__meta-value">${state.tokensToday.toLocaleString()}</span>
          </div>
        </div>
        <div class="agent-card__actions">
          <button class="btn ${toggleClass}" onclick="toggleAgent('${agent.id}')">${toggleLabel}</button>
        </div>
      </div>
    `;
  }).join('');
}

// ─── Toggle Agent (Kill Switch) ─────────────────────────────────────────────
function toggleAgent(agentId) {
  agentStates[agentId].active = !agentStates[agentId].active;
  renderAgents();
  console.log(`Agent ${agentId} is now ${agentStates[agentId].active ? 'ACTIVE' : 'INACTIVE'}`);
}

// ─── Load KPIs ──────────────────────────────────────────────────────────────
async function loadKPIs() {
  // Active leads
  const active = await supabaseQuery('leads?status=not.in.(rechazado,perdido,contrato_firmado)&select=id', { count: true });
  if (active) document.getElementById('kpiActiveLeads').textContent = active.count;

  // HOT leads (scl_score >= 7)
  const hot = await supabaseQuery('leads?scl_score=gte.7&status=not.in.(rechazado,perdido,contrato_firmado)&select=id', { count: true });
  if (hot) document.getElementById('kpiHotLeads').textContent = hot.count;

  // WARM leads (scl_score 4-6)
  const warm = await supabaseQuery('leads?scl_score=gte.4&scl_score=lt.7&status=not.in.(rechazado,perdido,contrato_firmado)&select=id', { count: true });
  if (warm) document.getElementById('kpiWarmLeads').textContent = warm.count;

  // COLD leads (scl_score < 4 or dormant)
  const cold = await supabaseQuery('leads?scl_score=lt.4&status=not.in.(rechazado,perdido,contrato_firmado)&select=id', { count: true });
  if (cold) document.getElementById('kpiColdLeads').textContent = cold.count;

  // Void properties
  const voidP = await supabaseQuery('properties?estado=eq.void&select=id', { count: true });
  if (voidP) document.getElementById('kpiVoidProperties').textContent = voidP.count;

  // Pending reactivations
  const react = await supabaseQuery('reactivation?estado=eq.pendiente&select=id', { count: true });
  if (react) document.getElementById('kpiReactivationsPending').textContent = react.count;
}

// ─── Load Void Properties Table ─────────────────────────────────────────────
async function loadVoidProperties() {
  const result = await supabaseQuery('properties?estado=eq.void&select=direccion,zona,precio_mensual,updated_at&order=updated_at.asc&limit=10');
  const tbody = document.getElementById('voidTableBody');

  if (!result || result.data.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" class="data-table__empty">No void properties</td></tr>';
    return;
  }

  tbody.innerHTML = result.data.map(p => {
    const daysVoid = Math.floor((Date.now() - new Date(p.updated_at).getTime()) / (1000 * 60 * 60 * 24));
    return `
      <tr>
        <td>${p.direccion || '—'}</td>
        <td>${p.zona || '—'}</td>
        <td>£${p.precio_mensual || '—'}</td>
        <td>${daysVoid}d</td>
      </tr>
    `;
  }).join('');
}

// ─── Load Reactivation Queue ────────────────────────────────────────────────
async function loadReactivations() {
  const result = await supabaseQuery('v_reactivation_pendientes?select=reactivation_id,lead_nombre,agente_asignado,estado&order=created_at.asc&limit=10');
  const tbody = document.getElementById('reactivationTableBody');

  if (!result || result.data.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" class="data-table__empty">No pending reactivations</td></tr>';
    return;
  }

  tbody.innerHTML = result.data.map(r => `
    <tr>
      <td>${r.lead_nombre || '—'}</td>
      <td>${r.agente_asignado}</td>
      <td><span class="badge badge--pending">${r.estado}</span></td>
      <td>
        <button class="btn btn--success" onclick="approveReactivation('${r.reactivation_id}')">Approve</button>
        <button class="btn btn--danger" onclick="rejectReactivation('${r.reactivation_id}')">Reject</button>
      </td>
    </tr>
  `).join('');
}

// ─── Reactivation Actions ───────────────────────────────────────────────────
async function approveReactivation(id) {
  if (!CONFIG.SUPABASE_URL || !CONFIG.SUPABASE_ANON_KEY) return;
  console.log(`Approving reactivation: ${id}`);
  // In production, this would PATCH the reactivation record
}

async function rejectReactivation(id) {
  if (!CONFIG.SUPABASE_URL || !CONFIG.SUPABASE_ANON_KEY) return;
  console.log(`Rejecting reactivation: ${id}`);
}

// ─── Load Agent Stats ───────────────────────────────────────────────────────
async function loadAgentStats() {
  // Leads per agent
  const leads = await supabaseQuery('leads?status=not.in.(rechazado,perdido,contrato_firmado)&select=asignado_a');
  if (leads) {
    const counts = {};
    leads.data.forEach(l => { counts[l.asignado_a] = (counts[l.asignado_a] || 0) + 1; });
    Object.entries(counts).forEach(([agent, count]) => {
      if (agentStates[agent]) agentStates[agent].leads = count;
    });
  }

  renderAgents();
}

// ─── Render API Tokens ──────────────────────────────────────────────────────
function renderTokens() {
  const grid = document.getElementById('tokensGrid');
  const tokens = [
    { name: 'Supabase Anon Key', value: CONFIG.SUPABASE_ANON_KEY || '(not configured)', scope: 'Public read' },
    { name: 'Supabase URL', value: CONFIG.SUPABASE_URL || '(not configured)', scope: 'API endpoint' },
  ];

  grid.innerHTML = tokens.map(t => `
    <div class="token-card">
      <div class="token-card__header">
        <span class="token-card__name">${t.name}</span>
      </div>
      <div class="token-card__value">${t.value ? t.value.substring(0, 40) + '...' : '—'}</div>
      <div class="token-card__meta">Scope: ${t.scope}</div>
    </div>
  `).join('');
}

// ─── Connection Status ──────────────────────────────────────────────────────
function updateConnectionStatus(online) {
  const el = document.getElementById('connectionStatus');
  if (online) {
    el.textContent = '● Online';
    el.className = 'header__connection header__connection--online';
  } else {
    el.textContent = '● Offline';
    el.className = 'header__connection header__connection--offline';
  }
}

// ─── Refresh All ────────────────────────────────────────────────────────────
async function refreshAll() {
  const isConfigured = CONFIG.SUPABASE_URL && CONFIG.SUPABASE_ANON_KEY;

  if (isConfigured) {
    updateConnectionStatus(true);
    await Promise.all([loadKPIs(), loadVoidProperties(), loadReactivations(), loadAgentStats()]);
  } else {
    updateConnectionStatus(false);
    renderAgents();
    // Show placeholder data when not configured
    document.getElementById('kpiActiveLeads').textContent = '—';
    document.getElementById('kpiHotLeads').textContent = '—';
    document.getElementById('kpiWarmLeads').textContent = '—';
    document.getElementById('kpiColdLeads').textContent = '—';
    document.getElementById('kpiVoidProperties').textContent = '—';
    document.getElementById('kpiReactivationsPending').textContent = '—';
    document.getElementById('voidTableBody').innerHTML = '<tr><td colspan="4" class="data-table__empty">Configure SUPABASE_URL and SUPABASE_ANON_KEY in script.js</td></tr>';
    document.getElementById('reactivationTableBody').innerHTML = '<tr><td colspan="4" class="data-table__empty">Configure Supabase to load data</td></tr>';
  }

  renderTokens();
  document.getElementById('lastRefresh').textContent = `Last refresh: ${new Date().toLocaleTimeString('en-GB', { timeZone: 'Europe/London' })}`;
}

// ─── Init ───────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  refreshAll();
  setInterval(refreshAll, CONFIG.REFRESH_INTERVAL);
});
