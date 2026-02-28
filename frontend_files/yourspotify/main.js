/* Your Spotify Homepage — Visitor Auth + Access Requests + Playlists */
(function () {
  "use strict";

  /* ── DOM References ── */
  var loginBtn = document.getElementById("login-btn");
  var userInfo = document.getElementById("user-info");
  var userName = document.getElementById("user-name");
  var loginHints = document.querySelectorAll(".login-hint");
  var policyBanner = document.getElementById("policy-banner");
  var policyAckBtn = document.getElementById("policy-ack-btn");
  var dataManagement = document.getElementById("data-management");
  var deleteDataBtn = document.getElementById("delete-data-btn");
  var accessRequestSection = document.getElementById("access-request-section");
  var accessRequestForm = document.getElementById("access-request-form");
  var formMessage = document.getElementById("form-message");
  var submitRequestBtn = document.getElementById("submit-request-btn");
  var playlistSection = document.getElementById("playlist-section");
  var playlistsContainer = document.getElementById("playlists-container");
  var totalRequestsEl = document.getElementById("total-requests");
  var approvedCountEl = document.getElementById("approved-count");
  var countryStatsEl = document.getElementById("country-stats");

  /* ── Auth Error Display ── */
  var urlParams = new URLSearchParams(window.location.search);
  var authError = urlParams.get("error");
  if (authError) {
    var errorMsg = {
      access_denied: "Spotify access was denied.",
      invalid_state: "Authentication session expired. Please try again.",
      token_exchange_failed: "Login failed. Please try again.",
      missing_params: "Something went wrong. Please try again.",
      no_refresh_token: "Could not complete login. Please try again.",
      profile_failed: "Could not retrieve your Spotify profile."
    };
    var msg = errorMsg[authError] || "Login error: " + authError;
    var banner = document.createElement("div");
    banner.className = "auth-error-banner";
    banner.textContent = msg;
    document.querySelector("main").prepend(banner);
    window.history.replaceState({}, document.title, window.location.pathname);
  }

  /* ── Demo Counter ── */
  function loadDemoCounter() {
    fetch("/api/access/count")
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (totalRequestsEl) totalRequestsEl.textContent = data.total_requests || 0;
        if (approvedCountEl) approvedCountEl.textContent = data.approved_count || 0;
      })
      .catch(function () { /* Silently fail */ });
  }
  loadDemoCounter();

  /* ── Country Stats ── */
  function loadCountryStats() {
    fetch("/api/stats/countries")
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (!countryStatsEl) return;
        var stats = data.country_stats || [];
        if (stats.length === 0) {
          countryStatsEl.innerHTML = '<p class="muted-text">No country data available yet. Be the first!</p>';
          return;
        }
        var html = '<div class="country-cards">';
        stats.forEach(function (s) {
          html += '<div class="country-card">';
          html += '<h4>' + escapeHtml(s.country) + '</h4>';
          html += '<span class="country-users">' + s.user_count + ' listener' + (s.user_count !== 1 ? 's' : '') + '</span>';
          if (s.top_genres && s.top_genres.length) {
            html += '<div class="country-genres">';
            s.top_genres.forEach(function (g) {
              html += '<span class="genre-tag">' + escapeHtml(g.name) + '</span>';
            });
            html += '</div>';
          }
          html += '</div>';
        });
        html += '</div>';
        countryStatsEl.innerHTML = html;
      })
      .catch(function () {
        if (countryStatsEl) countryStatsEl.innerHTML = '<p class="muted-text">Could not load stats.</p>';
      });
  }
  loadCountryStats();

  /* ── Auth Status Check ── */
  fetch("/api/auth/status", { credentials: "include" })
    .then(function (res) { return res.json(); })
    .then(function (data) {
      if (data.logged_in) {
        /* Logged in — hide login + request form, show user info */
        if (loginBtn) loginBtn.style.display = "none";
        if (userInfo) userInfo.style.display = "";
        if (userName) userName.textContent = "Hi, " + (data.display_name || "User");
        if (dataManagement) dataManagement.style.display = "";
        if (accessRequestSection) accessRequestSection.style.display = "none";

        /* Owner gets no logout button */
        if (data.is_owner) {
          var logoutBtn = document.querySelector(".spotify-logout-btn");
          if (logoutBtn) logoutBtn.style.display = "none";
          if (dataManagement) dataManagement.style.display = "none";
        }

        /* Policy update notification */
        if (data.policy_updated && !data.is_owner && policyBanner) {
          policyBanner.style.display = "";
        }

        /* Load playlist suggestions for authenticated users */
        if (playlistSection) {
          playlistSection.style.display = "";
          loadPlaylistSuggestions();
        }
      } else {
        /* Not logged in — show login */
        if (loginBtn) loginBtn.style.display = "";
        if (userInfo) userInfo.style.display = "none";
        loginHints.forEach(function (h) { h.style.display = ""; });
      }
    })
    .catch(function () {
      if (loginBtn) loginBtn.style.display = "";
    });

  /* ── Policy Acknowledgement ── */
  if (policyAckBtn) {
    policyAckBtn.addEventListener("click", function () {
      fetch("/api/auth/acknowledge-policy", {
        method: "POST",
        credentials: "include"
      })
        .then(function (res) {
          if (res.ok && policyBanner) {
            policyBanner.style.display = "none";
          }
        })
        .catch(function () { /* Silently fail */ });
    });
  }

  /* ── Access Request Form ── */
  if (accessRequestForm) {
    accessRequestForm.addEventListener("submit", function (e) {
      e.preventDefault();
      if (submitRequestBtn) submitRequestBtn.disabled = true;

      var payload = {
        full_name: document.getElementById("req-name").value.trim(),
        spotify_email: document.getElementById("req-email").value.trim(),
        country: document.getElementById("req-country").value
      };

      fetch("/api/access/request", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      })
        .then(function (res) { return res.json().then(function (d) { return { ok: res.ok, data: d }; }); })
        .then(function (result) {
          if (formMessage) {
            formMessage.style.display = "";
            if (result.ok) {
              formMessage.className = "form-message success";
              formMessage.textContent = "Request submitted! You\u2019ll receive an email once approved.";
              accessRequestForm.reset();
              loadDemoCounter();
            } else {
              formMessage.className = "form-message error";
              formMessage.textContent = result.data.error || "Submission failed.";
            }
          }
        })
        .catch(function () {
          if (formMessage) {
            formMessage.style.display = "";
            formMessage.className = "form-message error";
            formMessage.textContent = "Could not connect to server.";
          }
        })
        .finally(function () {
          if (submitRequestBtn) submitRequestBtn.disabled = false;
        });
    });
  }

  /* ── Data Deletion ── */
  if (deleteDataBtn) {
    deleteDataBtn.addEventListener("click", function () {
      if (!confirm("This will permanently delete all your stored data (profile, tokens, insights). This action cannot be undone.\n\nContinue?")) {
        return;
      }
      fetch("/api/me/data", {
        method: "DELETE",
        credentials: "include"
      })
        .then(function (res) {
          if (res.ok) {
            alert("Your data has been deleted. You will be logged out.");
            window.location.href = "/yourspotify/";
          } else {
            return res.json().then(function (d) {
              alert("Error: " + (d.error || "Could not delete data."));
            });
          }
        })
        .catch(function () {
          alert("Could not connect to the server. Please try again.");
        });
    });
  }

  /* ── Playlist Preferences & Suggestions ── */
  var availableGenres = [];
  var currentPrefs = null;

  /* Genre selector factory */
  function createGenreSelector(searchId, dropdownId, tagsId, prefKey, maxItems) {
    var searchInput = document.getElementById(searchId);
    var dropdown = document.getElementById(dropdownId);
    var tagsContainer = document.getElementById(tagsId);
    if (!searchInput || !dropdown || !tagsContainer) return null;

    var selected = [];

    function renderTags() {
      tagsContainer.innerHTML = "";
      selected.forEach(function (g) {
        var tag = document.createElement("span");
        tag.className = "genre-tag removable";
        tag.innerHTML = escapeHtml(g) + ' <button class="genre-remove" data-genre="' + escapeAttr(g) + '">&times;</button>';
        tagsContainer.appendChild(tag);
      });
      tagsContainer.querySelectorAll(".genre-remove").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var genre = btn.getAttribute("data-genre");
          selected = selected.filter(function (g) { return g !== genre; });
          renderTags();
          renderDropdown(searchInput.value);
        });
      });
    }

    function renderDropdown(filter) {
      var lc = (filter || "").toLowerCase();
      var matches = availableGenres.filter(function (g) {
        return g.toLowerCase().indexOf(lc) !== -1 && selected.indexOf(g) === -1;
      }).slice(0, 20);

      if (matches.length === 0 || (selected.length >= maxItems)) {
        dropdown.style.display = "none";
        return;
      }
      dropdown.innerHTML = "";
      matches.forEach(function (g) {
        var opt = document.createElement("div");
        opt.className = "genre-option";
        opt.textContent = g;
        opt.addEventListener("click", function () {
          if (selected.length < maxItems) {
            selected.push(g);
            renderTags();
            searchInput.value = "";
            renderDropdown("");
          }
        });
        dropdown.appendChild(opt);
      });
      dropdown.style.display = "";
    }

    searchInput.addEventListener("input", function () { renderDropdown(searchInput.value); });
    searchInput.addEventListener("focus", function () { renderDropdown(searchInput.value); });
    document.addEventListener("click", function (e) {
      if (!searchInput.contains(e.target) && !dropdown.contains(e.target)) {
        dropdown.style.display = "none";
      }
    });

    return {
      getSelected: function () { return selected.slice(); },
      setSelected: function (genres) {
        selected = (genres || []).slice(0, maxItems);
        renderTags();
      }
    };
  }

  var genreSelector = null;
  var discoverySelector = null;
  var excludedSelector = null;

  function initGenreSelectors() {
    genreSelector = createGenreSelector("genre-search", "genre-dropdown", "selected-genres", "genres", 15);
    discoverySelector = createGenreSelector("discovery-genre-search", "discovery-genre-dropdown", "selected-discovery-genres", "discovery_genres", 15);
    excludedSelector = createGenreSelector("excluded-genre-search", "excluded-genre-dropdown", "selected-excluded-genres", "excluded_genres", 15);
  }

  /* Timeframe pills */
  var timeframePills = document.getElementById("timeframe-pills");
  if (timeframePills) {
    timeframePills.addEventListener("click", function (e) {
      var pill = e.target.closest(".timeframe-pill");
      if (!pill) return;
      timeframePills.querySelectorAll(".timeframe-pill").forEach(function (p) { p.classList.remove("active"); });
      pill.classList.add("active");
    });
  }

  function getSelectedTimeframe() {
    var active = document.querySelector(".timeframe-pill.active");
    return active ? active.getAttribute("data-value") : "1m";
  }

  function setSelectedTimeframe(tf) {
    if (!timeframePills) return;
    timeframePills.querySelectorAll(".timeframe-pill").forEach(function (p) {
      p.classList.toggle("active", p.getAttribute("data-value") === tf);
    });
  }

  /* Load preferences from API */
  function loadPreferences() {
    return fetch("/api/me/playlists/preferences", { credentials: "include" })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        currentPrefs = data.preferences || {};
        availableGenres = data.available_genres || [];

        initGenreSelectors();

        setSelectedTimeframe(currentPrefs.timeframe || "1m");
        var excludeCheckbox = document.getElementById("exclude-listened");
        if (excludeCheckbox) excludeCheckbox.checked = currentPrefs.exclude_listened !== false;

        if (genreSelector) genreSelector.setSelected(currentPrefs.genres || []);
        if (discoverySelector) discoverySelector.setSelected(currentPrefs.discovery_genres || []);
        if (excludedSelector) excludedSelector.setSelected(currentPrefs.excluded_genres || []);
      })
      .catch(function () { initGenreSelectors(); });
  }

  /* Save preferences */
  var savePrefsBtn = document.getElementById("save-prefs-btn");
  if (savePrefsBtn) {
    savePrefsBtn.addEventListener("click", function () {
      var excludeCheckbox = document.getElementById("exclude-listened");
      var payload = {
        timeframe: getSelectedTimeframe(),
        exclude_listened: excludeCheckbox ? excludeCheckbox.checked : true,
        genres: genreSelector ? genreSelector.getSelected() : [],
        discovery_genres: discoverySelector ? discoverySelector.getSelected() : [],
        excluded_genres: excludedSelector ? excludedSelector.getSelected() : []
      };

      savePrefsBtn.disabled = true;
      savePrefsBtn.textContent = "Saving\u2026";

      fetch("/api/me/playlists/preferences", {
        method: "PUT",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          if (data.preferences) currentPrefs = data.preferences;
          savePrefsBtn.textContent = "\u2713 Saved!";
          setTimeout(function () { savePrefsBtn.textContent = "Save Preferences"; savePrefsBtn.disabled = false; }, 2000);
        })
        .catch(function () {
          savePrefsBtn.textContent = "Error";
          setTimeout(function () { savePrefsBtn.textContent = "Save Preferences"; savePrefsBtn.disabled = false; }, 2000);
        });
    });
  }

  /* Regenerate playlists */
  var regenerateBtn = document.getElementById("regenerate-btn");
  if (regenerateBtn) {
    regenerateBtn.addEventListener("click", function () {
      regenerateBtn.disabled = true;
      regenerateBtn.textContent = "Generating\u2026";
      if (playlistsContainer) playlistsContainer.innerHTML = '<p class="loading-text">Regenerating your playlists\u2026</p>';

      fetch("/api/me/playlists/regenerate", {
        method: "POST",
        credentials: "include"
      })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          renderPlaylists(data);
          regenerateBtn.textContent = "\uD83D\uDD04 Regenerate Playlists";
          regenerateBtn.disabled = false;
        })
        .catch(function () {
          if (playlistsContainer) playlistsContainer.innerHTML = '<p class="muted-text">Could not regenerate playlists.</p>';
          regenerateBtn.textContent = "\uD83D\uDD04 Regenerate Playlists";
          regenerateBtn.disabled = false;
        });
    });
  }

  /* Render stats */
  function renderStats(stats) {
    var statsEl = document.getElementById("playlist-stats");
    if (!statsEl || !stats) return;
    statsEl.style.display = "";
    var html = '<div class="stats-items">';
    html += '<span class="stat-item"><strong>' + (stats.total_plays || 0) + '</strong> plays</span>';
    html += '<span class="stat-item"><strong>' + (stats.unique_tracks || 0) + '</strong> unique tracks</span>';
    html += '<span class="stat-item"><strong>' + (stats.unique_genres || 0) + '</strong> genres</span>';
    html += '<span class="stat-item">' + escapeHtml(stats.timeframe_label || "") + '</span>';
    if (stats.supplemented) html += '<span class="stat-item stat-supplement">+ Spotify supplement</span>';
    html += '</div>';
    statsEl.innerHTML = html;
  }

  /* Render playlists */
  function renderPlaylists(data) {
    if (!playlistsContainer) return;
    var playlists = data.playlists || [];

    if (data.stats) renderStats(data.stats);

    if (playlists.length === 0) {
      playlistsContainer.innerHTML = '<p class="muted-text">' + (data.message || "No suggestions available yet.") + '</p>';
      return;
    }
    var html = '';
    playlists.forEach(function (pl) {
      html += '<div class="playlist-group">';
      html += '<div class="playlist-header">';
      html += '<div><h4>' + escapeHtml(pl.name) + '</h4>';
      html += '<p class="playlist-desc">' + escapeHtml(pl.description) + '</p></div>';
      html += '<button class="save-playlist-btn" data-playlist-id="' + pl.id + '"'
        + ' data-playlist-name="' + escapeAttr(pl.name) + '"'
        + ' data-playlist-desc="' + escapeAttr(pl.description) + '"'
        + '>&#10010; Save to Spotify</button>';
      html += '</div>';
      if (pl.message) {
        html += '<p class="muted-text">' + escapeHtml(pl.message) + '</p>';
      }
      html += '<div class="playlist-tracks">';
      (pl.tracks || []).forEach(function (t) {
        html += '<div class="playlist-track">';
        if (t.image) html += '<img src="' + escapeAttr(t.image) + '" alt="" class="track-thumb">';
        html += '<div class="track-info">';
        html += '<span class="track-name">' + escapeHtml(t.name) + '</span>';
        html += '<span class="track-artist">' + escapeHtml(t.artist) + '</span>';
        html += '</div>';
        if (t.url) html += '<a href="' + escapeAttr(t.url) + '" target="_blank" class="track-link" title="Open in Spotify">&#9654;</a>';
        html += '</div>';
      });
      html += '</div></div>';
    });
    playlistsContainer.innerHTML = html;

    /* Attach save handlers */
    playlistsContainer.querySelectorAll(".save-playlist-btn").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var plId = btn.getAttribute("data-playlist-id");
        var plName = btn.getAttribute("data-playlist-name");
        var plDesc = btn.getAttribute("data-playlist-desc");
        var pl = playlists.find(function (p) { return p.id === plId; });
        if (!pl) return;
        var uris = pl.tracks.map(function (t) { return t.uri; }).filter(Boolean);
        if (uris.length === 0) { alert("No tracks to save."); return; }
        btn.disabled = true;
        btn.textContent = "Saving\u2026";
        fetch("/api/me/playlists/save", {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ playlist_name: plName, description: plDesc, track_uris: uris })
        })
          .then(function (res) { return res.json(); })
          .then(function (d) {
            if (d.playlist_url) {
              btn.textContent = "\u2713 Saved!";
              btn.classList.add("saved");
              btn.onclick = function () { window.open(d.playlist_url, "_blank"); };
              btn.disabled = false;
            } else {
              btn.textContent = "Error";
              btn.disabled = false;
              setTimeout(function () { btn.textContent = "\u2795 Save to Spotify"; }, 2000);
            }
          })
          .catch(function () {
            btn.textContent = "Error";
            btn.disabled = false;
            setTimeout(function () { btn.textContent = "\u2795 Save to Spotify"; }, 2000);
          });
      });
    });
  }

  function loadPlaylistSuggestions() {
    loadPreferences().then(function () {
      fetch("/api/me/playlists/suggestions", { credentials: "include" })
        .then(function (res) { return res.json(); })
        .then(function (data) { renderPlaylists(data); })
        .catch(function () {
          if (playlistsContainer) playlistsContainer.innerHTML = '<p class="muted-text">Could not load playlists.</p>';
        });
    });
  }

  /* ── Collage ── */
  var DATA_URLS = ["/data/spotify_data.json"];
  var collageGrid = document.getElementById("collage-grid");

  function extractImages(data) {
    var images = [];
    if (data.albums) {
      data.albums.forEach(function (a) { if (a.image) images.push(a.image); });
    }
    if (data.artists) {
      data.artists.forEach(function (a) { if (a.image) images.push(a.image); });
    }
    if (data.tracks) {
      data.tracks.forEach(function (t) { if (t.image) images.push(t.image); });
    }
    return images;
  }

  function renderCollage(images) {
    if (!collageGrid) return;
    var unique = [];
    var seen = {};
    images.forEach(function (img) {
      if (!seen[img]) { seen[img] = true; unique.push(img); }
    });
    var selected = unique.slice(0, 24);
    collageGrid.innerHTML = "";
    selected.forEach(function (src) {
      var img = document.createElement("img");
      img.src = src;
      img.alt = "Album cover";
      img.loading = "lazy";
      collageGrid.appendChild(img);
    });
  }

  function loadCollage() {
    var allImages = [];
    var completed = 0;
    DATA_URLS.forEach(function (url) {
      var opts = {};
      if (url.indexOf("/api/") === 0) opts.credentials = "include";
      fetch(url, opts)
        .then(function (res) {
          if (!res.ok) throw new Error("HTTP " + res.status);
          return res.json();
        })
        .then(function (data) {
          allImages = allImages.concat(extractImages(data));
        })
        .catch(function () { /* Silently skip */ })
        .finally(function () {
          completed++;
          if (completed === DATA_URLS.length) renderCollage(allImages);
        });
    });
  }
  loadCollage();

  /* ── Utility ── */
  function escapeHtml(str) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str || ""));
    return div.innerHTML;
  }

  function escapeAttr(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }
})();
