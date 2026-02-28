/* ═══════════════════════════════════════════════════
   Portfolio Scripts — Babasanmi Adeyemi
   Multi-page navigation + reveal animations
   ═══════════════════════════════════════════════════ */
(function () {
  "use strict";

  /* ── Hamburger Menu ── */
  const hamburger = document.querySelector(".hamburger");
  const navLinks = document.querySelector(".nav-links");

  if (hamburger && navLinks) {
    hamburger.addEventListener("click", () => {
      const isOpen = navLinks.classList.toggle("open");
      hamburger.classList.toggle("active");
      hamburger.setAttribute("aria-expanded", isOpen);
    });

    navLinks.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        navLinks.classList.remove("open");
        hamburger.classList.remove("active");
        hamburger.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* ── Navbar scroll state ── */
  const navbar = document.getElementById("navbar");
  if (navbar) {
    const onScroll = () => {
      navbar.classList.toggle("scrolled", window.scrollY > 40);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  /* ── Active Nav Highlight (pathname-based for multi-page) ── */
  const navItems = document.querySelectorAll(".nav-links a");
  const path = window.location.pathname;

  navItems.forEach((a) => {
    a.classList.remove("active");
    const href = a.getAttribute("href");
    if (href === "/" && (path === "/" || path === "/index.html")) {
      a.classList.add("active");
    } else if (href !== "/" && path.startsWith(href)) {
      a.classList.add("active");
    }
  });

  /* ── Scroll-triggered Reveals ── */
  const revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible");
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    revealEls.forEach((el) => revealObserver.observe(el));
  } else {
    revealEls.forEach((el) => el.classList.add("visible"));
  }
})();
