(function () {
  "use strict";

  var DESKTOP_QUERY = "(min-width: 76.25em)";
  var MIN_WIDTH = 8 * 16;
  var MAX_WIDTH = 24 * 16;
  var DEFAULT_PRIMARY_WIDTH = 12.1 * 16;
  var DEFAULT_SECONDARY_WIDTH = 12.1 * 16;

  function clamp(value) {
    return Math.min(Math.max(value, MIN_WIDTH), MAX_WIDTH);
  }

  function readState(key, defaultWidth) {
    try {
      var stored = JSON.parse(localStorage.getItem(key));
      if (stored && typeof stored.width === "number") {
        return {
          width: clamp(stored.width),
          collapsed: stored.collapsed === true
        };
      }
    } catch (error) {
      // Ignore unavailable or malformed local storage.
    }

    return { width: defaultWidth, collapsed: false };
  }

  function writeState(key, state) {
    try {
      localStorage.setItem(key, JSON.stringify({
        width: state.width,
        collapsed: state.collapsed
      }));
    } catch (error) {
      // Ignore unavailable local storage.
    }
  }

  function setupSidebar(sidebar, side, key, defaultWidth, desktop) {
    var state = readState(key, defaultWidth);
    if (!sidebar.id) {
      sidebar.id = "docs-sidebar-" + side;
    }
    var controls = document.createElement("div");
    controls.className = "docs-sidebar-controls";

    var toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "docs-sidebar-toggle";
    toggle.setAttribute("aria-controls", sidebar.id);
    controls.appendChild(toggle);

    var handle = document.createElement("button");
    handle.type = "button";
    handle.className = "docs-sidebar-resize-handle";
    handle.setAttribute("role", "separator");
    handle.setAttribute("aria-orientation", "vertical");
    handle.setAttribute("aria-valuemin", String(MIN_WIDTH));
    handle.setAttribute("aria-valuemax", String(MAX_WIDTH));
    controls.appendChild(handle);
    sidebar.appendChild(controls);

    function apply() {
      if (!desktop.matches) {
        sidebar.classList.remove("docs-sidebar--collapsed");
        sidebar.style.removeProperty("width");
        controls.hidden = true;
        return;
      }

      controls.hidden = false;
      sidebar.classList.toggle("docs-sidebar--collapsed", state.collapsed);
      sidebar.style.width = state.collapsed ? "0px" : state.width + "px";
      toggle.setAttribute("aria-expanded", String(!state.collapsed));
      toggle.setAttribute("aria-label", state.collapsed ? "Expand " + side + " sidebar" : "Collapse " + side + " sidebar");
      toggle.title = state.collapsed ? "Expand " + side + " sidebar" : "Collapse " + side + " sidebar";
      toggle.textContent = state.collapsed ? "◨" : "◧";
      handle.setAttribute("aria-valuenow", String(Math.round(state.width)));
      handle.setAttribute("aria-label", "Resize " + side + " sidebar");
      handle.title = "Drag to resize " + side + " sidebar";
    }

    toggle.addEventListener("click", function () {
      state.collapsed = !state.collapsed;
      writeState(key, state);
      apply();
    });

    function resize(clientX) {
      if (side === "primary") {
        state.width = clamp(clientX - sidebar.getBoundingClientRect().left);
      } else {
        state.width = clamp(sidebar.getBoundingClientRect().right - clientX);
      }
      state.collapsed = false;
      apply();
    }

    handle.addEventListener("pointerdown", function (event) {
      if (!desktop.matches || state.collapsed) {
        return;
      }
      event.preventDefault();
      handle.setPointerCapture(event.pointerId);
      document.body.classList.add("docs-sidebar-resizing");
    });

    handle.addEventListener("pointermove", function (event) {
      if (handle.hasPointerCapture(event.pointerId)) {
        resize(event.clientX);
      }
    });

    function stopResize(event) {
      if (!handle.hasPointerCapture(event.pointerId)) {
        return;
      }
      handle.releasePointerCapture(event.pointerId);
      document.body.classList.remove("docs-sidebar-resizing");
      writeState(key, state);
    }

    handle.addEventListener("pointerup", stopResize);
    handle.addEventListener("pointercancel", stopResize);
    handle.addEventListener("keydown", function (event) {
      if (!desktop.matches || state.collapsed) {
        return;
      }
      var step = event.shiftKey ? 32 : 16;
      var direction = side === "primary" ? 1 : -1;
      if (event.key === "ArrowLeft") {
        state.width -= step * direction;
      } else if (event.key === "ArrowRight") {
        state.width += step * direction;
      } else if (event.key === "Home") {
        state.width = MIN_WIDTH;
      } else if (event.key === "End") {
        state.width = MAX_WIDTH;
      } else {
        return;
      }
      event.preventDefault();
      state.width = clamp(state.width);
      writeState(key, state);
      apply();
    });

    apply();
    desktop.addEventListener("change", apply);
  }

  function start() {
    var desktop = window.matchMedia(DESKTOP_QUERY);
    var primary = document.querySelector('.md-sidebar--primary[data-md-type="navigation"]');
    var secondary = document.querySelector('.md-sidebar--secondary[data-md-type="toc"]');

    if (primary) {
      setupSidebar(primary, "primary", "poorman-aws.primary-sidebar", DEFAULT_PRIMARY_WIDTH, desktop);
    }
    if (secondary) {
      setupSidebar(secondary, "secondary", "poorman-aws.secondary-sidebar", DEFAULT_SECONDARY_WIDTH, desktop);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
}());
