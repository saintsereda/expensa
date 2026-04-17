(function () {
    'use strict';

    const STORAGE_KEY = 'expensa_cookie_consent_v1';
    const CONSENT_VERSION = 1;

    const CATEGORIES = [
        {
            id: 'necessary',
            label: 'Strictly necessary',
            description: 'Required for the site to work (remembers your theme and this very consent choice). Always on.',
            locked: true
        },
        {
            id: 'analytics',
            label: 'Analytics',
            description: 'Anonymous statistics about how the site is used, so we can improve it. Currently unused — enabling this changes nothing today.',
            locked: false
        },
        {
            id: 'marketing',
            label: 'Marketing',
            description: 'Cookies from advertising or social networks. Currently unused — enabling this changes nothing today.',
            locked: false
        }
    ];

    function loadConsent() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            if (!raw) return null;
            const parsed = JSON.parse(raw);
            if (!parsed || parsed.version !== CONSENT_VERSION) return null;
            return parsed;
        } catch (_) {
            return null;
        }
    }

    function saveConsent(partial) {
        const payload = {
            necessary: true,
            analytics: !!partial.analytics,
            marketing: !!partial.marketing,
            timestamp: new Date().toISOString(),
            version: CONSENT_VERSION
        };
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
        } catch (_) {}
        window.dispatchEvent(new CustomEvent('expensa:cookie-consent', { detail: payload }));
        return payload;
    }

    function h(tag, attrs, children) {
        const el = document.createElement(tag);
        if (attrs) {
            for (const [k, v] of Object.entries(attrs)) {
                if (k === 'class') el.className = v;
                else if (k === 'text') el.textContent = v;
                else if (k === 'html') el.innerHTML = v;
                else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
                else el.setAttribute(k, v);
            }
        }
        if (children) {
            for (const c of children) {
                if (c) el.appendChild(c);
            }
        }
        return el;
    }

    function buildBanner(onAccept, onReject, onCustomize) {
        const text = h('p', {
            class: 'cookie-banner__text',
            html: 'We use essential storage to remember your preferences. You can opt in to analytics and marketing if you\u2019d like. See our <a href="/cookies.html">Cookie Policy</a>.'
        });

        const actions = h('div', { class: 'cookie-banner__actions' }, [
            h('button', {
                class: 'cookie-banner__btn cookie-banner__btn--ghost',
                type: 'button',
                onclick: onCustomize,
                text: 'Customize'
            }),
            h('button', {
                class: 'cookie-banner__btn cookie-banner__btn--secondary',
                type: 'button',
                onclick: onReject,
                text: 'Reject non-essential'
            }),
            h('button', {
                class: 'cookie-banner__btn cookie-banner__btn--primary',
                type: 'button',
                onclick: onAccept,
                text: 'Accept all'
            })
        ]);

        return h('aside', {
            class: 'cookie-banner',
            role: 'dialog',
            'aria-modal': 'false',
            'aria-labelledby': 'cookie-banner-title',
            'aria-describedby': 'cookie-banner-desc'
        }, [
            h('div', { class: 'cookie-banner__inner' }, [
                h('div', { class: 'cookie-banner__body' }, [
                    h('strong', { id: 'cookie-banner-title', class: 'cookie-banner__title', text: 'Cookies & storage' }),
                    text
                ]),
                actions
            ])
        ]);
    }

    function buildModal(currentConsent, onSave) {
        const state = {
            analytics: !!currentConsent.analytics,
            marketing: !!currentConsent.marketing
        };

        const rows = CATEGORIES.map((cat) => {
            const checkbox = h('input', {
                type: 'checkbox',
                id: `cookie-cat-${cat.id}`,
                class: 'cookie-modal__checkbox'
            });
            checkbox.checked = cat.locked ? true : !!state[cat.id];
            checkbox.disabled = cat.locked;
            if (!cat.locked) {
                checkbox.addEventListener('change', () => {
                    state[cat.id] = checkbox.checked;
                });
            }

            return h('label', { class: 'cookie-modal__row', for: `cookie-cat-${cat.id}` }, [
                h('div', { class: 'cookie-modal__row-header' }, [
                    h('span', { class: 'cookie-modal__row-label', text: cat.label }),
                    checkbox
                ]),
                h('p', { class: 'cookie-modal__row-desc', text: cat.description })
            ]);
        });

        const overlay = h('div', {
            class: 'cookie-modal',
            role: 'dialog',
            'aria-modal': 'true',
            'aria-labelledby': 'cookie-modal-title'
        }, [
            h('div', { class: 'cookie-modal__panel' }, [
                h('div', { class: 'cookie-modal__header' }, [
                    h('h2', { id: 'cookie-modal-title', class: 'cookie-modal__title', text: 'Cookie preferences' }),
                    h('button', {
                        class: 'cookie-modal__close',
                        type: 'button',
                        'aria-label': 'Close',
                        onclick: () => close(false),
                        html: '&times;'
                    })
                ]),
                h('p', {
                    class: 'cookie-modal__intro',
                    html: 'Choose what the site may use. Your preference is saved on this device. See our <a href="/cookies.html">Cookie Policy</a> for details.'
                }),
                h('div', { class: 'cookie-modal__rows' }, rows),
                h('div', { class: 'cookie-modal__footer' }, [
                    h('button', {
                        class: 'cookie-banner__btn cookie-banner__btn--secondary',
                        type: 'button',
                        onclick: () => close(true, { analytics: false, marketing: false }),
                        text: 'Reject all'
                    }),
                    h('button', {
                        class: 'cookie-banner__btn cookie-banner__btn--primary',
                        type: 'button',
                        onclick: () => close(true, state),
                        text: 'Save preferences'
                    })
                ])
            ])
        ]);

        function onKey(e) {
            if (e.key === 'Escape') close(false);
        }

        function close(shouldSave, saveState) {
            document.removeEventListener('keydown', onKey);
            overlay.remove();
            if (shouldSave) onSave(saveState || state);
        }

        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) close(false);
        });
        document.addEventListener('keydown', onKey);

        return overlay;
    }

    function hideBanner() {
        const existing = document.querySelector('.cookie-banner');
        if (!existing) return;
        existing.classList.add('cookie-banner--leaving');
        setTimeout(() => existing.remove(), 200);
    }

    function showBanner() {
        if (document.querySelector('.cookie-banner')) return;

        const banner = buildBanner(
            () => {
                saveConsent({ analytics: true, marketing: true });
                hideBanner();
            },
            () => {
                saveConsent({ analytics: false, marketing: false });
                hideBanner();
            },
            () => {
                hideBanner();
                openPreferences();
            }
        );
        document.body.appendChild(banner);
    }

    function openPreferences() {
        const current = loadConsent() || { analytics: false, marketing: false };
        const modal = buildModal(current, (choice) => {
            saveConsent(choice);
            modal.remove();
        });
        document.body.appendChild(modal);
    }

    function resetConsent() {
        try { localStorage.removeItem(STORAGE_KEY); } catch (_) {}
    }

    window.expensaCookies = {
        open: openPreferences,
        reset: () => {
            resetConsent();
            showBanner();
        },
        get: loadConsent
    };

    function init() {
        if (!loadConsent()) {
            showBanner();
        }

        document.querySelectorAll('[data-cookie-settings]').forEach((el) => {
            el.addEventListener('click', (e) => {
                e.preventDefault();
                openPreferences();
            });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
