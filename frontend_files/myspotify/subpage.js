/* Spotify Sub-page — Shared Renderer */
(function () {
  "use strict";

  var grid = document.getElementById("content-grid");
  var status = document.getElementById("status");
  if (!grid) return;

  var DATA_URL = grid.dataset.url;
  var DATA_TYPE = grid.dataset.type;

  function setStatus(msg) {
    if (status) status.textContent = msg;
  }

  /* ── Album Card ── */
  function renderAlbums(albums) {
    if (!albums || albums.length === 0) { setStatus("No albums found."); return; }
    setStatus("");
    albums.forEach(function (album) {
      var card = document.createElement("a");
      card.className = "album-card";
      card.href = album.url || "#";
      card.target = "_blank";
      card.rel = "noopener noreferrer";

      var img = document.createElement("img");
      img.src = album.image || "";
      img.alt = album.name;
      img.loading = "lazy";

      var info = document.createElement("div");
      info.className = "album-info";

      var title = document.createElement("h3");
      title.textContent = album.name;

      var artist = document.createElement("p");
      artist.className = "artist";
      artist.textContent = album.artist;

      var meta = document.createElement("p");
      meta.className = "release-date";
      meta.textContent = album.release_date || "";

      info.appendChild(title);
      info.appendChild(artist);
      if (meta.textContent) info.appendChild(meta);
      card.appendChild(img);
      card.appendChild(info);
      grid.appendChild(card);
    });
  }

  /* ── Track Card ── */
  function renderTracks(tracks) {
    if (!tracks || tracks.length === 0) { setStatus("No tracks found."); return; }
    setStatus("");
    tracks.forEach(function (track) {
      var card = document.createElement("a");
      card.className = "track-card";
      card.href = track.url || "#";
      card.target = "_blank";
      card.rel = "noopener noreferrer";

      var img = document.createElement("img");
      img.src = track.image || "";
      img.alt = track.name;
      img.loading = "lazy";

      var info = document.createElement("div");
      info.className = "track-info";

      var title = document.createElement("h3");
      title.textContent = track.name;

      var artist = document.createElement("p");
      artist.className = "artist";
      artist.textContent = track.artist;

      var meta = document.createElement("p");
      meta.className = "meta";
      if (track.played_at) {
        var d = new Date(track.played_at);
        meta.textContent = d.toLocaleDateString() + " " + d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      } else if (track.play_count) {
        meta.textContent = track.play_count + " plays";
      } else if (track.album) {
        meta.textContent = track.album;
      }

      info.appendChild(title);
      info.appendChild(artist);
      if (meta.textContent) info.appendChild(meta);
      card.appendChild(img);
      card.appendChild(info);
      grid.appendChild(card);
    });
  }

  /* ── Artist Card ── */
  function renderArtists(artists) {
    if (!artists || artists.length === 0) { setStatus("No artists found."); return; }
    setStatus("");
    artists.forEach(function (artist) {
      var card = document.createElement("a");
      card.className = "artist-card";
      card.href = artist.url || "#";
      card.target = "_blank";
      card.rel = "noopener noreferrer";

      var img = document.createElement("img");
      img.src = artist.image || "";
      img.alt = artist.name;
      img.loading = "lazy";

      var name = document.createElement("h3");
      name.textContent = artist.name;

      card.appendChild(img);
      card.appendChild(name);

      if (artist.genres && artist.genres.length > 0) {
        var genres = document.createElement("p");
        genres.className = "genres";
        genres.textContent = artist.genres.slice(0, 3).join(", ");
        card.appendChild(genres);
      }

      if (artist.popularity !== undefined) {
        var pop = document.createElement("p");
        pop.className = "popularity";
        pop.textContent = "Popularity: " + artist.popularity;
        card.appendChild(pop);
      }

      grid.appendChild(card);
    });
  }

  /* ── Genre Card ── */
  function renderGenres(genres) {
    if (!genres || genres.length === 0) { setStatus("No genre data found."); return; }
    setStatus("");
    genres.forEach(function (genre) {
      var card = document.createElement("div");
      card.className = "genre-card";

      var name = document.createElement("h3");
      name.textContent = genre.name;

      var count = document.createElement("p");
      count.className = "count";
      count.textContent = genre.count;

      card.appendChild(name);
      card.appendChild(count);

      if (genre.artists && genre.artists.length > 0) {
        var artists = document.createElement("p");
        artists.className = "artists-list";
        artists.textContent = genre.artists.join(", ");
        card.appendChild(artists);
      }

      grid.appendChild(card);
    });
  }

  /* ── Dispatcher ── */
  function render(data) {
    grid.innerHTML = "";
    switch (DATA_TYPE) {
      case "albums":
        renderAlbums(data.albums || []);
        break;
      case "tracks":
        renderTracks(data.tracks || []);
        break;
      case "artists":
        renderArtists(data.artists || []);
        break;
      case "genres":
        renderGenres(data.genres || []);
        break;
      default:
        setStatus("Unknown data type.");
    }
  }

  /* ── Fetch & Render ── */
  var fetchOptions = {};
  /* API endpoints require credentials (session cookie) */
  if (DATA_URL.indexOf("/api/") === 0) {
    fetchOptions.credentials = "include";
  }

  fetch(DATA_URL, fetchOptions)
    .then(function (res) {
      if (res.status === 401) {
        setStatus("");
        grid.innerHTML =
          '<div class="auth-prompt">' +
          '<p>Sign in with Spotify to see your personalized data.</p>' +
          '<a href="/api/auth/login" class="spotify-login-btn">Login with Spotify</a>' +
          '</div>';
        return null;
      }
      if (!res.ok) throw new Error("HTTP " + res.status);
      return res.json();
    })
    .then(function (data) {
      if (data) render(data);
    })
    .catch(function (err) {
      setStatus("Unable to load data. Please try again later.");
      console.error("Fetch error:", err);
    });
})();
