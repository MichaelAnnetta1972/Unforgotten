/**
 * Unforgotten — Minimal Dark Redesign
 * JavaScript: parallax, video toggle, scroll reveals, navigation
 */

document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initMobileMenu();
    initHeroParallax();
    initDeviceToggle();
    initScrollReveal();
    initSmoothScrolling();
    initFAQAccordion();
    initAnalytics();
});

/**
 * Navigation — frosted glass on scroll
 */
function initNavigation() {
    const nav = document.getElementById('nav');
    if (!nav) return;

    // Skip scroll behavior for solid nav (sub-pages)
    if (nav.classList.contains('nav--solid')) return;

    window.addEventListener('scroll', () => {
        if (window.pageYOffset > 80) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }
    }, { passive: true });
}

/**
 * Mobile menu toggle
 */
function initMobileMenu() {
    const toggle = document.querySelector('.nav-mobile-toggle');
    const menu = document.getElementById('mobileMenu');

    if (!toggle || !menu) return;

    toggle.addEventListener('click', () => {
        toggle.classList.toggle('active');
        menu.classList.toggle('active');
        document.body.style.overflow = menu.classList.contains('active') ? 'hidden' : '';

        // Update aria-expanded
        const expanded = toggle.classList.contains('active');
        toggle.setAttribute('aria-expanded', expanded);
    });

    // Close menu when clicking a link
    menu.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            toggle.classList.remove('active');
            menu.classList.remove('active');
            document.body.style.overflow = '';
            toggle.setAttribute('aria-expanded', 'false');
        });
    });
}

/**
 * Hero parallax — phones drift up, center phone scales
 *
 * Uses a wrapper div for the drift (translateY) so individual phone
 * CSS transforms (fan positioning) are not overridden.
 * The center phone (3rd child) gets an additional scale via JS.
 */
function initHeroParallax() {
    const hero = document.getElementById('hero');
    const wrapper = document.getElementById('heroPhonesWrapper');
    const phonesContainer = document.getElementById('heroPhones');

    if (!hero || !wrapper || !phonesContainer) return;

    const centerPhone = phonesContainer.children[2]; // 3rd phone = center
    let ticking = false;

    // Store the base CSS transform for the center phone
    const baseScale = 1.08; // matches CSS: width/height = phone * 1.08

    function updateParallax() {
        const scrollY = window.pageYOffset;
        const heroHeight = hero.offsetHeight;

        // Only animate while hero is in/near view
        if (scrollY > heroHeight + 200) {
            ticking = false;
            return;
        }

        // Progress: 0 at top, 1 when hero fully scrolled past
        const progress = Math.min(Math.max(scrollY / heroHeight, 0), 1);

        // Phones drift upward as user scrolls (max 80px)
        const drift = progress * 80;
        wrapper.style.transform = `translateY(-${drift}px)`;

        // Center phone scales up slightly (additional 8% on top of its base)
        if (centerPhone) {
            const extraScale = 1 + progress * 0.08;
            centerPhone.style.transform = `translateX(-50%) translateY(0px) scale(${extraScale})`;
        }

        ticking = false;
    }

    window.addEventListener('scroll', () => {
        if (!ticking) {
            requestAnimationFrame(updateParallax);
            ticking = true;
        }
    }, { passive: true });
}

/**
 * Device toggle — switch between iPhone and iPad video
 */
function initDeviceToggle() {
    const toggles = document.querySelectorAll('.device-toggle');
    const iphoneFrame = document.getElementById('iphoneFrame');
    const ipadFrame = document.getElementById('ipadFrame');
    const iphoneVideo = document.getElementById('iphoneVideo');
    const ipadVideo = document.getElementById('ipadVideo');

    if (!toggles.length || !iphoneFrame || !ipadFrame) return;

    toggles.forEach(toggle => {
        toggle.addEventListener('click', () => {
            const device = toggle.dataset.device;

            // Update active toggle
            toggles.forEach(t => t.classList.remove('active'));
            toggle.classList.add('active');

            if (device === 'iphone') {
                iphoneFrame.classList.remove('hidden');
                ipadFrame.classList.add('hidden');
                if (iphoneVideo) iphoneVideo.play().catch(() => {});
                if (ipadVideo) ipadVideo.pause();
            } else {
                ipadFrame.classList.remove('hidden');
                iphoneFrame.classList.add('hidden');
                if (ipadVideo) ipadVideo.play().catch(() => {});
                if (iphoneVideo) iphoneVideo.pause();
            }
        });
    });

    // Auto-play visible video when section enters viewport
    const section = document.querySelector('.device-section');
    if (section) {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const activeDevice = document.querySelector('.device-toggle.active')?.dataset.device;
                    if (activeDevice === 'iphone' && iphoneVideo) {
                        iphoneVideo.play().catch(() => {});
                    } else if (ipadVideo) {
                        ipadVideo.play().catch(() => {});
                    }
                } else {
                    if (iphoneVideo) iphoneVideo.pause();
                    if (ipadVideo) ipadVideo.pause();
                }
            });
        }, { threshold: 0.3 });

        observer.observe(section);
    }
}

/**
 * Scroll reveal — fade-up animation on scroll via IntersectionObserver
 */
function initScrollReveal() {
    const revealElements = document.querySelectorAll('.reveal');
    const staggerElements = document.querySelectorAll('.reveal-stagger');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.12,
        rootMargin: '0px 0px -60px 0px'
    });

    revealElements.forEach(el => observer.observe(el));
    staggerElements.forEach(el => observer.observe(el));
}

/**
 * Smooth scrolling for anchor links
 */
function initSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            if (href === '#') return;

            e.preventDefault();
            const target = document.querySelector(href);

            if (target) {
                const navHeight = document.getElementById('nav')?.offsetHeight || 0;
                const y = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;
                window.scrollTo({ top: y, behavior: 'smooth' });
            }
        });
    });
}

/**
 * FAQ accordion — close other items when one opens
 */
function initFAQAccordion() {
    const faqItems = document.querySelectorAll('.faq-item');

    faqItems.forEach(item => {
        item.addEventListener('toggle', () => {
            if (item.open) {
                faqItems.forEach(other => {
                    if (other !== item && other.open) {
                        other.open = false;
                    }
                });
            }
        });
    });
}

/**
 * Analytics tracking (placeholder)
 */
function initAnalytics() {
    document.querySelectorAll('.hero-cta, .nav-cta, .pricing-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            console.log(`[Analytics] CTA click: ${btn.textContent.trim()}`);
        });
    });
}
