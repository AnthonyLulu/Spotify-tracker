/* Match Center V3: existing tournament themes and logos, visual layer only. */
(function () {
  'use strict';
  const live = () => typeof local === 'undefined' ? null : local.liveMatch;
  const meta = () => live()?.stats?._meta || {};
  const select = (parent, query) => parent?.querySelector(query);
  function enhance() {
    const card = document.querySelector('.cb-live-card');
    const court = select(card, '.cb-court');
    if (!court) return;
    const m = meta(), t = m.tournament || {};
    const title = String(t.name || t.tournament_name || 'Court Boss Tour');
    const cat = String(t.category || t.circuit || 'MATCH');
    const city = String(t.city || t.country || '');
    const place = String(t.venue || city || 'Court central');
    const surface = court.classList.contains('clay') ? 'clay'
                  : court.classList.contains('grass') ? 'grass' : 'hard';
    const theme = court.dataset.cbTournamentSkin || 'tour';
    const key = [title,cat,city,place,surface,theme].join('|');
    card.dataset.cbV3Surface = surface;
    court.dataset.cbV3Surface = surface;
    card.dataset.cbV3Theme = theme;
    if (card.dataset.cbV3Key === key && select(court,'.cb-v3-court-brand')) return;
    card.dataset.cbV3Key = key;
    let note = select(card,'.cb-v3-match-identity');
    if (!note) {
      note = document.createElement('div');
      note.className = 'cb-v3-match-identity';
      select(card,'.cb-broadcast-head')?.append(note);
    }
    note.replaceChildren();
    const catLine = document.createElement('span');
    catLine.textContent = cat;
    const placeLine = document.createElement('span');
    placeLine.textContent = [city,t.venue].filter(Boolean).join(' · ') || 'Circuit professionnel';
    note.append(catLine,placeLine);
    let brand = select(court,'.cb-v3-court-brand');
    if (!brand) {
      brand = document.createElement('div');
      brand.className = 'cb-v3-court-brand';
      court.append(brand);
    }
    brand.replaceChildren();
    const logo = document.createElement('span');
    logo.className = 'cb-v3-court-logo';
    if (typeof window.tournamentLogoHtml === 'function') {
      logo.innerHTML = window.tournamentLogoHtml(t, 'cb-v3-official-logo');
    } else {
      logo.textContent = title.substring(0,3).toUpperCase();
    }
    const label = document.createElement('b');
    label.textContent = title;
    const location = document.createElement('small');
    location.textContent = city || place;
    brand.append(logo,label,location);
    let venue = select(court,'.cb-v3-venue-footer');
    if (!venue) {
      venue = document.createElement('span');
      venue.className = 'cb-v3-venue-footer';
      court.append(venue);
    }
    venue.textContent = place + ' • ' + (surface === 'clay' ? 'TERRE BATTUE' : surface === 'grass' ? 'GAZON' : 'DUR');
  }
  let pending = false;
  const schedule = () => {
    if (pending) return;
    pending = true;
    requestAnimationFrame(() => {pending = false; enhance();});
  };
  const root = document.getElementById('app');
  if (root) new MutationObserver(schedule).observe(root,{childList:true,subtree:true});
  schedule();
  window.cbTournamentPresentationV3 = {enhance};
})();
