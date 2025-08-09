'use strict';

// Bridge untuk MTA CEF: stub saat bukan di MTA
if (!window.mta) {
  window.mta = {
    triggerEvent: (...args) => console.log('[stub] mta.triggerEvent', ...args)
  };
}

const state = {
  credits: 0,
  available: [] // item: { name, durationLabel, costLabel, id }
};

// API dipanggil dari Lua
window.initData = function initData(data) {
  try {
    if (typeof data === 'string') data = JSON.parse(data);
  } catch (e) {}
  applyData(data);
  renderAll();
};

window.refreshAll = function refreshAll(data) {
  try {
    if (typeof data === 'string') data = JSON.parse(data);
  } catch (e) {}
  applyData(data);
  renderAll();
};

window.updateAvailable = function updateAvailable(availableOrObj, creditsMaybe) {
  try {
    if (typeof availableOrObj === 'string') availableOrObj = JSON.parse(availableOrObj);
  } catch (e) {}

  let list = availableOrObj;
  let creditsLocal = creditsMaybe;

  if (availableOrObj && typeof availableOrObj === 'object' && !Array.isArray(availableOrObj)) {
    // Mendukung bentuk { list, credits } atau { available, credits }
    list = availableOrObj.list ?? availableOrObj.available ?? [];
    creditsLocal = (availableOrObj.credits !== undefined) ? availableOrObj.credits : creditsMaybe;
  }

  if (typeof creditsLocal === 'string') creditsLocal = Number(creditsLocal) || 0;

  state.available = normalizeAvailable(list || []);
  if (creditsLocal !== undefined) state.credits = Number(creditsLocal) || state.credits;
  renderHeader();
  renderAvailable();
};

function applyData(data) {
  if (!data || typeof data !== 'object') return;
  state.credits = Number(data.credits) || 0;
  state.available = normalizeAvailable(data.available || []);
}

function normalizeAvailable(list) {
  // Mendukung dua bentuk input:
  // - Sudah berupa objek: {name, durationLabel, costLabel, id}
  // - Bentuk array ala Lua: { name, costNumberOrText, durationNumber, id }
  return (list || []).map((it) => {
    if (it && typeof it === 'object' && !Array.isArray(it)) {
      return {
        name: it.name ?? '',
        durationLabel: it.durationLabel ?? (it.duration ? (it.duration > 1 ? `${it.duration} days` : 'Permanent') : ''),
        costLabel: it.costLabel ?? String(it.cost ?? ''),
        id: Number(it.id ?? it.perkId ?? it[3]) || 0
      };
    }
    if (Array.isArray(it)) {
      const name = it[0] ?? '';
      const cost = it[1];
      const duration = it[2];
      const id = Number(it[3]) || 0;
      const durationLabel = (Number(duration) > 1 ? `${duration} days` : 'Permanent');
      const costLabel = (typeof cost === 'number') ? `${cost} Coin` : String(cost ?? '');
      return { name, durationLabel, costLabel, id };
    }
    return { name: String(it ?? ''), durationLabel: '', costLabel: '', id: 0 };
  });
}

function renderAll() {
  renderHeader();
  renderAvailable();
  wireGlobalActions();
}

function renderHeader() {
  const creditsEl = document.getElementById('creditsValue');
  if (creditsEl) creditsEl.textContent = String(state.credits);
}

function renderAvailable() {
  const tbody = document.querySelector('#availableTable tbody');
  if (!tbody) return;
  tbody.innerHTML = '';

  state.available.forEach((item) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${escapeHtml(item.name)}</td>
      <td>${escapeHtml(item.durationLabel)}</td>
      <td>${escapeHtml(item.costLabel)}</td>
      <td>${escapeHtml(String(item.id))}</td>
    `;

    tr.addEventListener('dblclick', () => openPurchaseModal(item));
    tbody.appendChild(tr);
  });
}

function wireGlobalActions() {
  const btnClose = document.getElementById('btnClose');
  if (btnClose && !btnClose._wired) {
    btnClose._wired = true;
    btnClose.addEventListener('click', () => {
      mta.triggerEvent('donation:close');
    });
  }

  const btnDonate = document.getElementById('btnDonate');
  if (btnDonate && !btnDonate._wired) {
    btnDonate._wired = true;
    btnDonate.addEventListener('click', () => {
      // Tampilkan info panel donasi di Lua (state 1)
      mta.triggerEvent('donation:info', 1);
    });
  }
}

// Modal
let currentItem = null;
function openPurchaseModal(item) {
  currentItem = item;
  const modal = document.getElementById('purchaseModal');
  if (!modal) return;
  setText('mPerkName', item.name);
  setText('mDuration', item.durationLabel);
  setText('mCost', item.costLabel);

  modal.classList.remove('hidden');

  const confirmBtn = document.getElementById('mConfirm');
  const cancelBtn = document.getElementById('mCancel');

  if (confirmBtn && !confirmBtn._wired) {
    confirmBtn._wired = true;
    confirmBtn.addEventListener('click', () => {
      if (!currentItem) return;
      // Kirim ke Lua untuk proses server-side
      mta.triggerEvent('donation:purchase', Number(currentItem.id) || 0, null);
      closePurchaseModal();
    });
  }

  if (cancelBtn && !cancelBtn._wired) {
    cancelBtn._wired = true;
    cancelBtn.addEventListener('click', () => closePurchaseModal());
  }
}

function closePurchaseModal() {
  const modal = document.getElementById('purchaseModal');
  if (modal) modal.classList.add('hidden');
  currentItem = null;
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = String(text ?? '');
}

function escapeHtml(str) {
  return String(str)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

// Demo lokal saat bukan dari Lua
(function bootstrapIfStandalone(){
  try {
    // MTA biasanya akan memanggil window.initData. Jika tidak, isi sample.
    const isFromLua = !!window.__fromLua;
    if (isFromLua) return;
    const sample = {
      credits: 25,
      available: [
        { name: 'Max Interiors +1', durationLabel: 'Permanent', costLabel: '6 Coin', id: 14 },
        { name: 'Private Number', durationLabel: 'Permanent', costLabel: '1 Coin', id: 33 },
        { name: 'Custom Chat Icon', durationLabel: 'Permanent', costLabel: '3 Coin', id: 29 },
      ]
    };
    window.initData(sample);
  } catch (e) {}
})();