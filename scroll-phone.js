// Scroll-pinned phone with canvas frame scrubbing.
// Requires: <section class="phone-scroll"> with .phone-scroll__canvas and
// optional .phone-scroll__step children.

(function () {
    'use strict';

    const FRAME_COUNT = 159;
    const FRAME_PATH = (i) =>
        `/assets/scroll-frames/frame-${String(i).padStart(3, '0')}.webp`;

    const section = document.querySelector('.phone-scroll');
    const canvas = document.querySelector('.phone-scroll__canvas');
    // Sort by data-step so DOM order (which alternates columns) doesn't break sequencing.
    const steps = Array.from(document.querySelectorAll('.phone-scroll__step'))
        .sort((a, b) => (parseInt(a.dataset.step, 10) || 0) - (parseInt(b.dataset.step, 10) || 0));

    if (!section || !canvas) {
        console.warn('[scroll-phone] section or canvas not found');
        return;
    }

    const ctx = canvas.getContext('2d');
    const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const isMobile = matchMedia('(max-width: 768px)').matches;

    // Static fallback: render the first frame, skip preload + scroll wiring.
    if (reduceMotion || isMobile) {
        const img = new Image();
        img.decoding = 'async';
        img.addEventListener('load', () => {
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        });
        img.addEventListener('error', () => {
            console.error('[scroll-phone] failed to load fallback frame', img.src);
        });
        img.src = FRAME_PATH(1);
        if (steps.length) steps.forEach((s) => s.setAttribute('aria-current', 'true'));
        return;
    }

    const images = new Array(FRAME_COUNT);
    let wantedFrame = 0;

    function drawFrame(index) {
        wantedFrame = index;
        const img = images[index];
        if (img && img.complete && img.naturalWidth > 0) {
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            return true;
        }
        // Fallback: find the nearest loaded frame so the canvas isn't blank.
        for (let offset = 1; offset < FRAME_COUNT; offset++) {
            const before = images[index - offset];
            if (before && before.complete && before.naturalWidth > 0) {
                ctx.drawImage(before, 0, 0, canvas.width, canvas.height);
                return true;
            }
            const after = images[index + offset];
            if (after && after.complete && after.naturalWidth > 0) {
                ctx.drawImage(after, 0, 0, canvas.width, canvas.height);
                return true;
            }
        }
        return false;
    }

    function preload() {
        for (let i = 0; i < FRAME_COUNT; i++) {
            const img = new Image();
            img.decoding = 'async';
            // Attach handler BEFORE src so cached/instant loads still fire it.
            img.addEventListener('load', () => {
                // If nothing's been drawn yet, or this frame is the one we want,
                // redraw. drawFrame falls back to nearest available.
                drawFrame(wantedFrame);
            });
            img.addEventListener('error', () => {
                console.error('[scroll-phone] failed to load', img.src);
            });
            img.src = FRAME_PATH(i + 1);
            images[i] = img;
        }
    }

    function setActiveStep(progress) {
        if (!steps.length) return;
        steps.forEach((step, i) => {
            const start = i / steps.length;
            const end = (i + 1) / steps.length;
            const active =
                (progress >= start && progress < end) ||
                (i === steps.length - 1 && progress >= 1);
            if (active) step.setAttribute('aria-current', 'true');
            else step.removeAttribute('aria-current');
        });
    }

    let ticking = false;
    function update() {
        const rect = section.getBoundingClientRect();
        const vh = window.innerHeight;
        const total = rect.height - vh;
        const traveled = Math.min(Math.max(-rect.top, 0), total);
        const progress = total > 0 ? traveled / total : 0;

        const frame = Math.min(FRAME_COUNT - 1, Math.floor(progress * FRAME_COUNT));
        drawFrame(frame);
        setActiveStep(progress);

        ticking = false;
    }

    function onScroll() {
        if (!ticking) {
            requestAnimationFrame(update);
            ticking = true;
        }
    }

    preload();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();
})();
