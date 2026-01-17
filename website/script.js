/**
 * Unforgotten Marketing Website
 * JavaScript functionality for navigation, animations, and interactions
 */

document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initScrollEffects();
    initMobileMenu();
    initGalleryTabs();
    initGalleryNavigation();
    initSmoothScrolling();
    initRevealAnimations();
    initHeroVideo();
});

/**
 * Hero phone video handling
 * Shows fallback content if video fails to load
 */
function initHeroVideo() {
    const video = document.querySelector('.phone-video');
    const fallback = document.querySelector('.phone-screen-fallback');

    if (!video) return;

    // Initially hide fallback - let video try to load
    if (fallback) {
        fallback.style.display = 'none';
    }

    // Handle video load error - show fallback
    video.addEventListener('error', (e) => {
        console.log('Video error:', e);
        showFallback();
    });

    // Also listen for source errors
    const sources = video.querySelectorAll('source');
    sources.forEach(source => {
        source.addEventListener('error', () => {
            console.log('Source error for:', source.src);
            showFallback();
        });
    });

    // Handle video loaded successfully - ensure fallback is hidden
    video.addEventListener('loadeddata', () => {
        console.log('Video loaded successfully');
        video.classList.remove('video-error');
        if (fallback) {
            fallback.style.display = 'none';
        }
    });

    video.addEventListener('canplay', () => {
        console.log('Video can play');
        video.classList.remove('video-error');
        if (fallback) {
            fallback.style.display = 'none';
        }
    });

    // Try to play video
    video.play().catch((err) => {
        console.log('Autoplay failed:', err);
        // Don't show fallback for autoplay policy errors - video will still show
        // Only show fallback if there's actually no video to display
    });

    function showFallback() {
        video.classList.add('video-error');
        if (fallback) {
            fallback.style.display = 'flex';
        }
    }

    // Pause video when not in viewport (performance)
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                video.play().catch(() => {
                    // Autoplay may fail due to browser policy, that's ok
                });
            } else {
                video.pause();
            }
        });
    }, { threshold: 0.25 });

    observer.observe(video);
}

/**
 * Navigation scroll effects
 */
function initNavigation() {
    const nav = document.getElementById('nav');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        // Add scrolled class when past hero
        if (currentScroll > 100) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }

        // Optional: Hide nav on scroll down, show on scroll up
        // Disabled for simplicity, but can be enabled:
        // if (currentScroll > lastScroll && currentScroll > 200) {
        //     nav.style.transform = 'translateY(-100%)';
        // } else {
        //     nav.style.transform = 'translateY(0)';
        // }

        lastScroll = currentScroll;
    });
}

/**
 * Mobile menu toggle
 */
function initMobileMenu() {
    const toggle = document.querySelector('.nav-mobile-toggle');
    const mobileMenu = document.getElementById('mobileMenu');
    const mobileLinks = mobileMenu?.querySelectorAll('a');

    if (!toggle || !mobileMenu) return;

    toggle.addEventListener('click', () => {
        toggle.classList.toggle('active');
        mobileMenu.classList.toggle('active');
        document.body.style.overflow = mobileMenu.classList.contains('active') ? 'hidden' : '';
    });

    // Close menu when clicking a link
    mobileLinks?.forEach(link => {
        link.addEventListener('click', () => {
            toggle.classList.remove('active');
            mobileMenu.classList.remove('active');
            document.body.style.overflow = '';
        });
    });
}

/**
 * Smooth scrolling for anchor links
 */
function initSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href === '#') return;

            e.preventDefault();
            const target = document.querySelector(href);

            if (target) {
                const navHeight = document.getElementById('nav')?.offsetHeight || 0;
                const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

/**
 * Scroll-triggered reveal animations
 */
function initRevealAnimations() {
    const revealElements = document.querySelectorAll('.reveal');

    if (!revealElements.length) {
        // If no .reveal elements exist, add them to key sections
        addRevealClasses();
    }

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                // Optional: unobserve after reveal
                // observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    document.querySelectorAll('.reveal').forEach(el => {
        observer.observe(el);
    });
}

/**
 * Add reveal classes to elements that should animate on scroll
 */
function addRevealClasses() {
    const selectors = [
        '.section-header',
        '.problem-text',
        '.problem-stats',
        '.feature-card',
        '.step',
        '.designed-text',
        '.designed-visual',
        '.testimonial-card',
        '.pricing-card',
        '.gallery-header',
        '.cta-content'
    ];

    selectors.forEach(selector => {
        document.querySelectorAll(selector).forEach((el, index) => {
            el.classList.add('reveal');
            el.style.setProperty('--child-index', index);
        });
    });
}

/**
 * Parallax and scroll effects
 */
function initScrollEffects() {
    const hero = document.querySelector('.hero');
    const shapes = document.querySelectorAll('.shape');

    if (!hero || !shapes.length) return;

    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        const heroHeight = hero.offsetHeight;

        // Only apply effects while in hero section
        if (scrolled < heroHeight) {
            const progress = scrolled / heroHeight;

            shapes.forEach((shape, index) => {
                const speed = 0.3 + (index * 0.1);
                shape.style.transform = `translate(${scrolled * speed * 0.1}px, ${scrolled * speed}px)`;
            });
        }
    });
}

/**
 * Gallery tab switching (iPhone/iPad views)
 */
function initGalleryTabs() {
    const tabs = document.querySelectorAll('.gallery-tab');
    const galleries = document.querySelectorAll('.gallery-track');

    if (!tabs.length) return;

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const target = tab.dataset.target;

            // Update active tab
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            // Show corresponding gallery
            galleries.forEach(gallery => {
                if (gallery.dataset.device === target) {
                    gallery.style.display = 'flex';
                } else {
                    gallery.style.display = 'none';
                }
            });

            // Update navigation button states for the new gallery
            updateGalleryNavButtons();
        });
    });
}

/**
 * Gallery navigation arrows
 */
function initGalleryNavigation() {
    const prevBtn = document.querySelector('.gallery-nav-prev');
    const nextBtn = document.querySelector('.gallery-nav-next');

    if (!prevBtn || !nextBtn) return;

    // Get the currently visible gallery track
    function getActiveTrack() {
        const tracks = document.querySelectorAll('.gallery-track');
        for (const track of tracks) {
            const computedDisplay = window.getComputedStyle(track).display;
            if (computedDisplay !== 'none') {
                return track;
            }
        }
        return tracks[0];
    }

    // Scroll by one item width
    function scrollGallery(direction) {
        const track = getActiveTrack();
        if (!track) return;

        const item = track.querySelector('.gallery-item');
        if (!item) return;

        const scrollAmount = item.offsetWidth + 24; // item width + gap
        const newScrollLeft = track.scrollLeft + (direction * scrollAmount);

        track.scrollTo({
            left: newScrollLeft,
            behavior: 'smooth'
        });
    }

    prevBtn.addEventListener('click', () => scrollGallery(-1));
    nextBtn.addEventListener('click', () => scrollGallery(1));

    // Update button states based on scroll position
    function updateNavButtons() {
        const track = getActiveTrack();
        if (!track) return;

        const isAtStart = track.scrollLeft <= 10;
        const isAtEnd = track.scrollLeft >= track.scrollWidth - track.clientWidth - 10;

        prevBtn.disabled = isAtStart;
        nextBtn.disabled = isAtEnd;
    }

    // Listen to scroll events on all tracks
    document.querySelectorAll('.gallery-track').forEach(track => {
        track.addEventListener('scroll', updateNavButtons);
    });

    // Initial state
    updateNavButtons();

    // Expose update function globally for tab switching
    window.updateGalleryNavButtons = updateNavButtons;
}

/**
 * Update gallery nav buttons (called from tab switch)
 */
function updateGalleryNavButtons() {
    if (window.updateGalleryNavButtons) {
        // Small delay to let the display change take effect
        setTimeout(window.updateGalleryNavButtons, 50);
    }
}

/**
 * Animate numbers on scroll (for statistics)
 */
function initCounterAnimation() {
    const counters = document.querySelectorAll('.stat-number');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateCounter(entry.target);
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.5 });

    counters.forEach(counter => {
        observer.observe(counter);
    });
}

function animateCounter(element) {
    const text = element.textContent;
    const hasM = text.includes('M');
    const hasPercent = text.includes('%');

    let target = parseFloat(text.replace(/[^0-9.]/g, ''));
    let current = 0;
    const duration = 2000;
    const step = target / (duration / 16);

    const animate = () => {
        current += step;
        if (current < target) {
            let display = current.toFixed(hasM ? 1 : 0);
            if (hasM) display += 'M';
            if (hasPercent) display += '%';
            element.textContent = display;
            requestAnimationFrame(animate);
        } else {
            element.textContent = text;
        }
    };

    animate();
}

/**
 * Preload critical images
 */
function preloadImages(urls) {
    urls.forEach(url => {
        const img = new Image();
        img.src = url;
    });
}

/**
 * Handle gallery horizontal scroll with touch/mouse
 */
function initGalleryDrag() {
    const tracks = document.querySelectorAll('.gallery-track');

    tracks.forEach(track => {
        let isDown = false;
        let startX;
        let scrollLeft;

        track.addEventListener('mousedown', (e) => {
            isDown = true;
            track.style.cursor = 'grabbing';
            startX = e.pageX - track.offsetLeft;
            scrollLeft = track.scrollLeft;
        });

        track.addEventListener('mouseleave', () => {
            isDown = false;
            track.style.cursor = 'grab';
        });

        track.addEventListener('mouseup', () => {
            isDown = false;
            track.style.cursor = 'grab';
        });

        track.addEventListener('mousemove', (e) => {
            if (!isDown) return;
            e.preventDefault();
            const x = e.pageX - track.offsetLeft;
            const walk = (x - startX) * 2;
            track.scrollLeft = scrollLeft - walk;
        });
    });
}

// Initialize counter animation on load
document.addEventListener('DOMContentLoaded', () => {
    initCounterAnimation();
    initGalleryDrag();
});

/**
 * Analytics helper (placeholder for actual analytics)
 */
function trackEvent(category, action, label) {
    // Replace with actual analytics implementation
    // Example: gtag('event', action, { event_category: category, event_label: label });
    console.log(`[Analytics] ${category}: ${action} - ${label}`);
}

// Track CTA clicks
document.querySelectorAll('.btn-primary, .app-store-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        trackEvent('CTA', 'click', btn.textContent.trim());
    });
});
