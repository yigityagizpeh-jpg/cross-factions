/* ============================================================
   cross-factions  |  Tablet JavaScript (html/js/app.js)
   ============================================================ */

'use strict';

// ── Durum ───────────────────────────────────────────────────
let veri           = {};
let benimFactionId = null;
let benimCitizenId = null;
let aktifTab       = 'factionlar';
let onlineOyuncular = {};  // { citizenId: true } – sunucudan gelen online listesi

const YETKI_ISIMLERI = {
  1: 'Üye', 2: 'Askeri', 3: 'Subay', 4: 'Komutan', 5: 'Lider'
};

const RENK_LISTESI = [
  '#e74c3c','#e67e22','#f1c40f','#2ecc71',
  '#1abc9c','#3498db','#9b59b6','#e91e63',
  '#00bcd4','#8bc34a','#ff5722','#607d8b',
  '#795548','#ff9800','#cddc39','#009688',
];

// ── NUI mesaj alıcı ─────────────────────────────────────────
window.addEventListener('message', (ev) => {
  const data = ev.data;
  if (!data || !data.type) return;

  switch (data.type) {
    case 'tablet':
      if (data.durum === 'ac')    tabletAc();
      if (data.durum === 'kapat') tabletKapat();
      break;
    case 'tabletVeri':
      veri            = data.veri;
      benimFactionId  = data.veri.benimFactionId;
      benimCitizenId  = data.veri.benimCitizenId || null;
      onlineOyuncular = data.veri.onlineOyuncular || {};
      render();
      break;
    case 'syncVeri':
      veri.factionlar     = data.veri.factionlar    || veri.factionlar;
      veri.territoriler   = data.veri.territoriler  || veri.territoriler;
      veri.aktifSavaslar  = data.veri.aktifSavaslar || veri.aktifSavaslar;
      onlineOyuncular     = data.veri.onlineOyuncular || onlineOyuncular;
      render();
      break;
    case 'savasGuncelle':
      if (veri.aktifSavaslar) veri.aktifSavaslar[data.savasId] = data.veri;
      if (aktifTab === 'savaslar') renderSavaslar();
      break;
  }
});

// ── Tablet aç/kapat ─────────────────────────────────────────
function tabletAc() {
  document.getElementById('tablet').classList.remove('hidden');
}

function tabletKapat() {
  document.getElementById('tablet').classList.add('hidden');
}

function nuiPost(event, data = {}) {
  const resName = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'cross-factions';
  return fetch(`https://${resName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

// ── Özel bildirim ve dialog (alert/confirm/prompt yerine) ─────
function showAlert(msg, type) {
  const el = document.getElementById('cfToast');
  if (!el) return;
  el.textContent = msg;
  el.className = 'cf-toast cf-toast-' + (type || 'error') + ' show';
  clearTimeout(el._dismissTimer);
  el._dismissTimer = setTimeout(() => el.classList.remove('show'), 3500);
}

function showConfirm(msg, onEvet) {
  const modal = document.getElementById('cfModal');
  if (!modal) { if (window.confirm(msg)) onEvet(); return; }
  document.getElementById('cfModalMsg').textContent = msg;
  modal.classList.remove('hidden');
  const okBtn     = document.getElementById('cfModalOk');
  const cancelBtn = document.getElementById('cfModalCancel');
  const newOk     = okBtn.cloneNode(true);
  const newCancel = cancelBtn.cloneNode(true);
  okBtn.parentNode.replaceChild(newOk, okBtn);
  cancelBtn.parentNode.replaceChild(newCancel, cancelBtn);
  newOk.addEventListener('click', () => { modal.classList.add('hidden'); onEvet(); });
  newCancel.addEventListener('click', () => modal.classList.add('hidden'));
}

function showPrompt(msg, defaultVal, onOk) {
  const modal = document.getElementById('cfPromptModal');
  if (!modal) { const r = window.prompt(msg, defaultVal); if (r !== null) onOk(r); return; }
  document.getElementById('cfPromptMsg').textContent = msg;
  const input = document.getElementById('cfPromptInput');
  input.value = (defaultVal !== undefined && defaultVal !== null) ? String(defaultVal) : '';
  modal.classList.remove('hidden');
  setTimeout(() => input.focus(), 50);
  const okBtn     = document.getElementById('cfPromptOk');
  const cancelBtn = document.getElementById('cfPromptCancel');
  const newOk     = okBtn.cloneNode(true);
  const newCancel = cancelBtn.cloneNode(true);
  okBtn.parentNode.replaceChild(newOk, okBtn);
  cancelBtn.parentNode.replaceChild(newCancel, cancelBtn);
  const doOk = () => { modal.classList.add('hidden'); onOk(input.value); };
  newOk.addEventListener('click', doOk);
  newCancel.addEventListener('click', () => modal.classList.add('hidden'));
  input.onkeydown = (e) => {
    if (e.key === 'Enter') doOk();
    if (e.key === 'Escape') modal.classList.add('hidden');
  };
}

// ── Sekme değiştirme ────────────────────────────────────────
document.querySelectorAll('.nav-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.add('hidden'));
    btn.classList.add('active');
    aktifTab = btn.dataset.tab;
    document.getElementById('tab-' + aktifTab).classList.remove('hidden');
    render();
  });
});

// ── Kapat butonu ─────────────────────────────────────────────
document.getElementById('closeBtn').addEventListener('click', () => {
  nuiPost('tabletKapat');
  tabletKapat();
});

// ── Ana render ──────────────────────────────────────────────
function render() {
  switch (aktifTab) {
    case 'factionlar':   renderFactionlar();   break;
    case 'benimFaction': renderBenimFaction(); break;
    case 'territoriler': renderTerritoriler(); break;
    case 'savaslar':     renderSavaslar();     break;
    case 'sezon':        renderSezon();        break;
    case 'gorevler':     renderGorevler();     break;
  }
}

// ── Renk seçici ─────────────────────────────────────────────
function renkSeciciOlustur(containerId, hiddenId, secilenRenk) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.innerHTML = '';
  RENK_LISTESI.forEach(renk => {
    const el = document.createElement('div');
    el.className = 'renk-secici-item' + (renk === secilenRenk ? ' secili' : '');
    el.style.background = renk;
    el.title = renk;
    el.addEventListener('click', () => {
      container.querySelectorAll('.renk-secici-item').forEach(i => i.classList.remove('secili'));
      el.classList.add('secili');
      document.getElementById(hiddenId).value = renk;
    });
    container.appendChild(el);
  });
  if (secilenRenk) document.getElementById(hiddenId).value = secilenRenk;
}

// ── Online / Offline yardımcısı ──────────────────────────────
function onlineIsa(citizenId) {
  return onlineOyuncular && onlineOyuncular[citizenId]
    ? '<span class="dot-online" title="Çevrimiçi">●</span>'
    : '<span class="dot-offline" title="Çevrimdışı">●</span>';
}

// ───────────────────────────────────────────────────────────
//  FACTIONLAR
// ───────────────────────────────────────────────────────────
function renderFactionlar() {
  const el = document.getElementById('factionListesi');
  if (!el) return;
  const factionlar = veri.factionlar || {};
  const keys = Object.keys(factionlar);
  if (keys.length === 0) {
    el.innerHTML = '<p style="color:#7a8fa6;font-size:13px;">Henüz faction yok.</p>';
    return;
  }
  el.innerHTML = keys.map(fid => {
    const f = factionlar[fid];
    const uyeSayisi = (f.uyeler || []).length;
    const logoHtml = f.logo_url
      ? `<img src="${escHtml(f.logo_url)}" class="faction-logo" onerror="this.style.display='none'" style="width:40px;height:40px;border-radius:6px;margin-bottom:6px;" />`
      : '';
    const uyelerHtml = (f.uyeler || []).slice(0, 8).map(u =>
      `<span style="font-size:10px;color:#8899aa">${onlineIsa(u.citizen_id)} ${escHtml(u.isim)}</span>`
    ).join(' &nbsp; ') + (uyeSayisi > 8 ? `<span style="font-size:10px;color:#555"> +${uyeSayisi - 8} daha</span>` : '');
    const onlineSayisi = (f.uyeler || []).filter(u => onlineOyuncular && onlineOyuncular[u.citizen_id]).length;
    return `
      <div class="card">
        ${logoHtml}
        <div class="card-title">
          <span class="color-dot" style="background:${escHtml(f.renk)}"></span>
          ${escHtml(f.isim)}
        </div>
        <div class="card-info">
          <div>👑 Lider: <b>${escHtml(getLiderIsim(f))}</b></div>
          <div>👥 Üye: ${uyeSayisi} &nbsp;<span style="color:#2ecc71;font-size:10px">(${onlineSayisi} çevrimiçi)</span></div>
          <div>🏆 Kazanma: ${f.wins || 0}</div>
          <div>⚔ Sezon: ${f.sezon_wins || 0}</div>
          ${uyeSayisi > 0 ? `<div style="margin-top:6px;line-height:1.9">${uyelerHtml}</div>` : ''}
        </div>
      </div>`;
  }).join('');
}

function getLiderIsim(f) {
  if (!f.uyeler) return '?';
  for (const u of f.uyeler) {
    if (u.citizen_id === f.lider_citizen) return u.isim;
  }
  return f.lider_citizen || '?';
}

// ───────────────────────────────────────────────────────────
//  BENİM FACTION
// ───────────────────────────────────────────────────────────
function renderBenimFaction() {
  const yeniForm   = document.getElementById('yeniFactionForm');
  const fPanel     = document.getElementById('factionPaneli');

  if (!benimFactionId) {
    // Oluşturma formu göster
    yeniForm.classList.remove('hidden');
    fPanel.classList.add('hidden');
    renkSeciciOlustur('renkSecici', 'seciliRenk', RENK_LISTESI[0]);
    bindFactionOlustur();
    return;
  }

  yeniForm.classList.add('hidden');
  fPanel.classList.remove('hidden');

  const factionlar = veri.factionlar || {};
  const f = factionlar[benimFactionId];
  if (!f) return;

  const benimYetki = getBenimYetki(f);

  // Header
  const logoHtml = f.logo_url
    ? `<img src="${escHtml(f.logo_url)}" class="faction-logo" onerror="this.outerHTML='<div class=faction-logo-placeholder>⚔</div>'" />`
    : `<div class="faction-logo-placeholder">⚔</div>`;
  document.getElementById('factionHeaderPanel').innerHTML = `
    ${logoHtml}
    <div class="faction-info-block">
      <div class="faction-name" style="color:${escHtml(f.renk)}">${escHtml(f.isim)}</div>
      <div class="faction-meta">
        💰 Faction Kasası: $${(f.para || 0).toLocaleString()}<br/>
        👥 Üye: ${(f.uyeler || []).length}<br/>
        🏆 Kazanma: ${f.wins || 0} | Sezon: ${f.sezon_wins || 0}
      </div>
    </div>`;

  // Buton görünürlükleri
  document.getElementById('factionSilBtn').style.display = benimYetki >= 5 ? '' : 'none';
  document.getElementById('factionGuncelleBtn').style.display = benimYetki >= 5 ? '' : 'none';

  // Üye tablosu
  renderUyeTablosu(f, benimYetki);
  bindFactionPanelEvents(f, benimYetki);
}

function getBenimYetki(f) {
  if (!f || !f.uyeler) return 0;
  const cid = benimCitizenId || (veri && veri.benimCitizenId);
  if (!cid) return 0;
  for (const u of f.uyeler) {
    if (u.citizen_id === cid) return u.yetki;
  }
  return 1;
}

function renderUyeTablosu(f, benimYetki) {
  const tbody = document.getElementById('uyeTableBody');
  if (!tbody) return;
  const uyeler = f.uyeler || [];
  if (uyeler.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#555">Üye yok</td></tr>';
    return;
  }
  tbody.innerHTML = uyeler.map(u => {
    const yetkiIsim = YETKI_ISIMLERI[u.yetki] || u.yetki;
    const islemler = benimYetki >= 3 && u.yetki < benimYetki ? `
      <button class="btn-danger akcion-btn" onclick="uyeKov('${escAttr(u.citizen_id)}')">Kov</button>
      ${benimYetki >= 4 ? `
        <button class="btn-secondary akcion-btn" onclick="yetkiAta('${escAttr(u.citizen_id)}', ${u.yetki})">Yetki</button>
        <button class="btn-secondary akcion-btn" onclick="maasGuncelle('${escAttr(u.citizen_id)}', ${u.maas})">Maaş</button>
      ` : ''}
    ` : '<span style="color:#555;font-size:10px">-</span>';
    return `<tr>
      <td>${onlineIsa(u.citizen_id)} ${escHtml(u.isim)}</td>
      <td><span class="badge badge-info">${escHtml(yetkiIsim)}</span></td>
      <td>$${(u.maas || 0).toLocaleString()}</td>
      <td>${islemler}</td>
    </tr>`;
  }).join('');
}

function bindFactionOlustur() {
  const btn = document.getElementById('factionOlusturBtn');
  if (!btn || btn._bound) return;
  btn._bound = true;
  btn.addEventListener('click', () => {
    const isim    = document.getElementById('yeniFactionIsim').value.trim();
    const renk    = document.getElementById('seciliRenk').value;
    const logoUrl = document.getElementById('yeniFactionLogo').value.trim();
    if (!isim || !renk) { showAlert('İsim ve renk zorunludur!'); return; }
    nuiPost('factionOlustur', { isim, renk, logo_url: logoUrl });
  });
}

function bindFactionPanelEvents(f, benimYetki) {
  // Ayrıl
  const ayrilBtn = document.getElementById('factionAyrilBtn');
  if (ayrilBtn) {
    ayrilBtn.onclick = () => {
      showConfirm('Faction\'dan ayrılmak istediğinize emin misiniz?', () => nuiPost('factionAyril'));
    };
  }
  // Sil
  const silBtn = document.getElementById('factionSilBtn');
  if (silBtn) {
    silBtn.onclick = () => {
      showConfirm('Faction\'ı silmek istediğinize emin misiniz? Bu işlem geri alınamaz!', () => nuiPost('factionSil'));
    };
  }
  // Güncelle
  const gBtn = document.getElementById('factionGuncelleBtn');
  if (gBtn) {
    gBtn.onclick = () => {
      const gf = document.getElementById('guncelleForm');
      gf.classList.toggle('hidden');
      if (!gf.classList.contains('hidden')) {
        document.getElementById('guncelLogo').value = f.logo_url || '';
        renkSeciciOlustur('guncelRenkSecici', 'guncelSeciliRenk', f.renk);
      }
    };
  }
  // Güncelle kaydet
  const kaydetBtn = document.getElementById('guncelleKaydetBtn');
  if (kaydetBtn) {
    kaydetBtn.onclick = () => {
      nuiPost('factionGuncelle', {
        renk:     document.getElementById('guncelSeciliRenk').value || f.renk,
        logo_url: document.getElementById('guncelLogo').value.trim(),
      });
      document.getElementById('guncelleForm').classList.add('hidden');
    };
  }
  // İptal
  const iptalBtn = document.getElementById('guncelleIptalBtn');
  if (iptalBtn) {
    iptalBtn.onclick = () => document.getElementById('guncelleForm').classList.add('hidden');
  }
  // Davet
  const davetBtn = document.getElementById('davetEtBtn');
  if (davetBtn) {
    davetBtn.onclick = () => {
      const cid = document.getElementById('davetCitizenId').value.trim();
      if (!cid) return;
      nuiPost('uyeDavetEt', { citizenId: cid });
      document.getElementById('davetCitizenId').value = '';
    };
  }
}

// Kov
window.uyeKov = function(citizenId) {
  showConfirm(citizenId + ' adlı üyeyi kovmak istediğinize emin misiniz?', () => nuiPost('uyeKov', { citizenId }));
};

// Yetki ata
window.yetkiAta = function(citizenId, mevcutYetki) {
  showPrompt('Yeni yetki seviyesi (1-5, mevcut: ' + mevcutYetki + '):', mevcutYetki, (yeniYetki) => {
    const y = parseInt(yeniYetki);
    if (isNaN(y) || y < 1 || y > 5) { showAlert('Geçersiz yetki! (1-5 arası olmalıdır)'); return; }
    nuiPost('yetkiAta', { citizenId, yetki: y });
  });
};

// Maaş güncelle
window.maasGuncelle = function(citizenId, mevcutMaas) {
  showPrompt('Yeni maaş ($, mevcut: ' + mevcutMaas + '):', mevcutMaas, (yeni) => {
    const m = parseInt(yeni);
    if (isNaN(m) || m < 0) { showAlert('Geçersiz miktar! (0 veya üzeri olmalıdır)'); return; }
    nuiPost('maasGuncelle', { citizenId, maas: m });
  });
};

// ───────────────────────────────────────────────────────────
//  TERRİTORİLER
// ───────────────────────────────────────────────────────────
function renderTerritoriler() {
  const el = document.getElementById('territoryListesi');
  if (!el) return;
  const territoriler = veri.territoriler || {};
  const factionlar   = veri.factionlar   || {};
  const keys = Object.keys(territoriler);
  if (keys.length === 0) {
    el.innerHTML = '<p style="color:#7a8fa6;font-size:13px;">Bölge yok.</p>';
    return;
  }
  el.innerHTML = keys.map(tId => {
    const t = territoriler[tId];
    const owner = t.ownerFactionId && factionlar[t.ownerFactionId];
    const ownerText = owner ? `<span style="color:${escHtml(owner.renk)}">${escHtml(owner.isim)}</span>` : '<span style="color:#555">Sahipsiz</span>';
    const progress = Math.floor(t.captureProgress || 0);
    const fillColor = owner ? owner.renk : '#3498db';
    const sahibimiBu = owner && String(t.ownerFactionId) === String(benimFactionId);
    const captureBtn = benimFactionId && !sahibimiBu
      ? `<button class="btn-warning" onclick="captureBaslat(${tId})">Ele Geçir</button>`
      : (sahibimiBu ? '<span class="badge badge-success">Sizin</span>' : '');
    return `
      <div class="card">
        <div class="card-title">📍 ${escHtml(t.isim)}</div>
        <div class="card-info">
          <div>👑 Sahip: ${ownerText}</div>
          <div>🎯 Seviye: ${t.level || 1}</div>
          <div>📏 Yarıçap: ${t.radius || 80}m</div>
          <div style="margin:6px 0">
            <div style="font-size:10px;color:#7a8fa6;margin-bottom:2px">Capture: %${progress}</div>
            <div class="progress-wrap">
              <div class="progress-fill" style="width:${progress}%;background:${escHtml(fillColor)}"></div>
            </div>
          </div>
        </div>
        <div class="card-actions">${captureBtn}</div>
      </div>`;
  }).join('');
}

window.captureBaslat = function(tId) {
  if (!benimFactionId) { showAlert('Bir faction üyesi değilsiniz!'); return; }
  nuiPost('captureBaslat', { tId });
};

// ───────────────────────────────────────────────────────────
//  SAVAŞLAR
// ───────────────────────────────────────────────────────────
function renderSavaslar() {
  const el         = document.getElementById('savasListesi');
  const hedefSel   = document.getElementById('savasHedefFaction');
  const territorySel = document.getElementById('savasTerritory');
  const factionlar = veri.factionlar   || {};
  const territoriler = veri.territoriler || {};
  const savaslar   = veri.aktifSavaslar || veri.savaslar || [];

  // Aktif savaşlar
  if (el) {
    const savasArr = Array.isArray(savaslar) ? savaslar : Object.values(savaslar);
    if (savasArr.length === 0) {
      el.innerHTML = '<p style="color:#7a8fa6;font-size:13px;">Aktif savaş yok.</p>';
    } else {
      el.innerHTML = savasArr.map(s => {
        const sal  = factionlar[s.saldiranId];
        const sav  = factionlar[s.savunucuId];
        const ter  = s.territoryId && territoriler[s.territoryId];
        return `
          <div class="card">
            <div class="card-title">⚔ Savaş #${s.id}</div>
            <div class="card-info">
              <div><span style="color:${sal ? escHtml(sal.renk) : '#fff'}">${sal ? escHtml(sal.isim) : '?'}</span>
                <b style="color:#555"> vs </b>
                <span style="color:${sav ? escHtml(sav.renk) : '#fff'}">${sav ? escHtml(sav.isim) : '?'}</span>
              </div>
              <div>🗡 Kill: ${s.saldiranKill || 0} – ${s.savunucuKill || 0}</div>
              ${ter ? `<div>📍 Bölge: ${escHtml(ter.isim)}</div>` : ''}
            </div>
          </div>`;
      }).join('');
    }
  }

  // Savaş ilan formu görünürlüğü
  const ilanFormuEl = document.getElementById('savasIlanFormu');
  const ilanUyariEl = document.getElementById('savasIlanUyarisi');
  if (!benimFactionId) {
    if (ilanFormuEl) ilanFormuEl.classList.add('hidden');
    if (ilanUyariEl) {
      ilanUyariEl.classList.remove('hidden');
      ilanUyariEl.textContent = '⚠ Savaş ilan edebilmek için bir faction\'a üye olmanız gerekmektedir.';
      ilanUyariEl.style.cssText = 'color:#7a8fa6;font-size:12px;margin-top:8px';
    }
    return;
  }
  if (ilanFormuEl) ilanFormuEl.classList.remove('hidden');
  if (ilanUyariEl) ilanUyariEl.classList.add('hidden');

  // Savaş ilan formu – dropdown doldur
  if (hedefSel) {
    const mevcutHedef = hedefSel.value;
    hedefSel.innerHTML = '<option value="">Hedef faction seç...</option>';
    Object.keys(factionlar).forEach(fid => {
      if (String(fid) !== String(benimFactionId)) {
        const f   = factionlar[fid];
        const opt = document.createElement('option');
        opt.value = fid;
        opt.textContent = f.isim;
        if (fid === mevcutHedef) opt.selected = true;
        hedefSel.appendChild(opt);
      }
    });
  }

  if (territorySel) {
    const mevcutTer = territorySel.value;
    territorySel.innerHTML = '<option value="">Bölge seç (isteğe bağlı)...</option>';
    Object.keys(territoriler).forEach(tId => {
      const t   = territoriler[tId];
      const opt = document.createElement('option');
      opt.value = tId;
      opt.textContent = t.isim;
      if (tId === mevcutTer) opt.selected = true;
      territorySel.appendChild(opt);
    });
  }

  // Savaş ilan butonu
  const ilanBtn = document.getElementById('savasIlanBtn');
  if (ilanBtn && !ilanBtn._bound) {
    ilanBtn._bound = true;
    ilanBtn.addEventListener('click', () => {
      const hedef = document.getElementById('savasHedefFaction').value;
      const ter   = document.getElementById('savasTerritory').value || null;
      if (!benimFactionId) { showAlert('Bir faction üyesi değilsiniz!'); return; }
      if (!hedef) { showAlert('Hedef faction seçiniz!', 'warning'); return; }
      showConfirm(
        (factionlar[hedef]?.isim || 'Hedef') + ' factionına savaş ilan etmek istediğinize emin misiniz?',
        () => nuiPost('savasIlanEt', { hedefFactionId: parseInt(hedef), territoryId: ter ? parseInt(ter) : null })
      );
    });
  }
}

// ───────────────────────────────────────────────────────────
//  SEZON
// ───────────────────────────────────────────────────────────
function renderSezon() {
  const el = document.getElementById('sezonListesi');
  if (!el) return;
  const factionlar = veri.factionlar || {};

  // Sırala
  const sira = Object.values(factionlar)
    .sort((a, b) => (b.sezon_wins || 0) - (a.sezon_wins || 0));

  if (sira.length === 0) {
    el.innerHTML = '<p style="color:#7a8fa6;font-size:13px;">Faction yok.</p>';
    return;
  }

  const rankClass = (i) => i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : '';
  const rankEmoji = (i) => i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : (i + 1) + '.';

  el.innerHTML = `<div style="background:#111c28;border:1px solid #2a3a4f;border-radius:10px;overflow:hidden">` +
    sira.map((f, i) => `
      <div class="lb-row">
        <div class="lb-rank ${rankClass(i)}">${rankEmoji(i)}</div>
        <span class="color-dot" style="background:${escHtml(f.renk)}"></span>
        <div class="lb-isim">${escHtml(f.isim)}</div>
        <div class="lb-win">⚔ ${f.sezon_wins || 0} galibiyet</div>
      </div>`).join('') +
  `</div>`;
}

// ───────────────────────────────────────────────────────────
//  GÖREVLER
// ───────────────────────────────────────────────────────────
function renderGorevler() {
  const aktifEl = document.getElementById('aktifGorev');
  const listeEl = document.getElementById('gorevListesi');
  const gorevler = veri.gorevler || [];
  const aktifGorev = veri.aktifGorev || null;

  // Aktif görev
  if (aktifEl) {
    if (aktifGorev) {
      aktifEl.classList.remove('hidden');
      const gecen = Math.floor((Date.now() / 1000) - (aktifGorev.baslangic || 0));
      const kalan = Math.max(0, (aktifGorev.sure || 0) - gecen);
      aktifEl.innerHTML = `
        <div style="font-weight:700;color:#3498db;margin-bottom:4px">✅ Aktif Görev: ${escHtml(aktifGorev.isim)}</div>
        <div>${escHtml(aktifGorev.aciklama)}</div>
        <div style="margin-top:6px;color:#7a8fa6">
          💰 Ödül: $${(aktifGorev.odulPara || 0).toLocaleString()} |
          ⏱ Kalan: ${formatSure(kalan)}
        </div>
        <div style="margin-top:8px">
          <button class="btn-primary" onclick="gorevTamamla(${aktifGorev.id})">Görevi Tamamla</button>
        </div>`;
    } else {
      aktifEl.classList.add('hidden');
    }
  }

  // Görev listesi
  if (listeEl) {
    if (gorevler.length === 0) {
      listeEl.innerHTML = '<p style="color:#7a8fa6;font-size:13px;">Görev yok.</p>';
      return;
    }
    listeEl.innerHTML = gorevler.map(g => `
      <div class="card">
        <div class="card-title">📋 ${escHtml(g.isim)}</div>
        <div class="card-info">
          <div>${escHtml(g.aciklama)}</div>
          <div style="margin-top:6px">💰 $${(g.odulPara || 0).toLocaleString()} | ⏱ ${formatSure(g.sure)}</div>
        </div>
        <div class="card-actions">
          ${!aktifGorev && benimFactionId
            ? `<button class="btn-primary" onclick="gorevAl(${g.id})">Görevi Al</button>`
            : '<span style="color:#555;font-size:11px">Önce aktif görevi tamamlayın</span>'
          }
        </div>
      </div>`).join('');
  }
}

window.gorevAl = function(gorevId) {
  nuiPost('gorevAl', { gorevId });
};

window.gorevTamamla = function(gorevId) {
  showConfirm('Görevi tamamlandı olarak işaretlemek istiyor musunuz?', () => nuiPost('gorevTamamla', { gorevId }));
};

// ── Yardımcı ─────────────────────────────────────────────────
function formatSure(saniye) {
  if (!saniye || saniye <= 0) return '0s';
  const s = saniye % 60;
  const m = Math.floor(saniye / 60) % 60;
  const h = Math.floor(saniye / 3600);
  if (h > 0) return `${h}h ${m}dk`;
  if (m > 0) return `${m}dk ${s}s`;
  return `${s}s`;
}

function escHtml(str) {
  return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function escAttr(str) {
  return String(str || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}
