'use strict';
const command = document.querySelector('#install-command');
const copyButton = document.querySelector('.copy-command');
const copyStatus = document.querySelector('#copy-status');
let resetCopy;
copyButton.addEventListener('click', async () => {
  clearTimeout(resetCopy);
  copyStatus.classList.remove('copy-error');
  try {
    await navigator.clipboard.writeText(command.textContent.trim());
    copyButton.querySelector('span').textContent = 'Copied';
    copyButton.querySelector('use').setAttribute('href', 'assets/icons.svg#i-check');
    copyStatus.textContent = 'Copied. Open Terminal, paste, and press Return.';
    resetCopy = setTimeout(() => {
      copyButton.querySelector('span').textContent = 'Copy install command';
      copyButton.querySelector('use').setAttribute('href', 'assets/icons.svg#i-copy');
      copyStatus.textContent = '';
    }, 7000);
  } catch {
    command.closest('details').open = true;
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(command);
    selection.removeAllRanges();
    selection.addRange(range);
    command.focus();
    copyStatus.textContent = 'Copy access is unavailable. Select the command and press ⌘C, or touch and hold to copy.';
    copyStatus.classList.add('copy-error');
  }
});

const tabs = [...document.querySelectorAll('[role="tab"]')];
function activateTab(tab, focus = false) {
  for (const candidate of tabs) {
    const active = candidate === tab;
    candidate.setAttribute('aria-selected', String(active));
    candidate.tabIndex = active ? 0 : -1;
    document.getElementById(candidate.getAttribute('aria-controls')).hidden = !active;
  }
  if (focus) tab.focus();
}
for (const tab of tabs) {
  tab.addEventListener('click', () => activateTab(tab));
  tab.addEventListener('keydown', event => {
    let next;
    const index = tabs.indexOf(tab);
    if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length];
    if (event.key === 'ArrowLeft') next = tabs[(index + tabs.length - 1) % tabs.length];
    if (event.key === 'Home') next = tabs[0];
    if (event.key === 'End') next = tabs[tabs.length - 1];
    if (next) { event.preventDefault(); activateTab(next, true); }
  });
}
