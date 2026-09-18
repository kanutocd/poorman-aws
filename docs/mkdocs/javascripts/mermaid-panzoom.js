(function () {
  "use strict";

  var MIN_SCALE = 0.5;
  var MAX_SCALE = 4;
  var SCALE_STEP = 0.2;
  var ENHANCED = "data-mermaid-panzoom-ready";

  function clamp(value, minimum, maximum) {
    return Math.min(Math.max(value, minimum), maximum);
  }

  function updateScale(state, nextScale, originX, originY) {
    var scale = clamp(nextScale, MIN_SCALE, MAX_SCALE);
    var ratio = scale / state.scale;

    state.x = originX - (originX - state.x) * ratio;
    state.y = originY - (originY - state.y) * ratio;
    state.scale = scale;
  }

  function render(state) {
    state.diagram.style.transform =
      "translate3d(" + state.x + "px, " + state.y + "px, 0) scale(" + state.scale + ")";
    var zoomPercentage = Math.round(state.scale * 100);
    state.zoom.textContent = zoomPercentage + "%";
    state.zoomOut.disabled = state.scale <= MIN_SCALE;
    state.zoomIn.disabled = state.scale >= MAX_SCALE;
    state.reset.disabled = zoomPercentage === 100;
  }

  function enhance(diagram) {
    if (diagram.tagName === "PRE" || diagram.hasAttribute(ENHANCED)) {
      return;
    }

    var originalParent = diagram.parentNode;
    if (!originalParent) {
      return;
    }

    diagram.setAttribute(ENHANCED, "");

    var viewport = document.createElement("div");
    viewport.className = "mermaid-panzoom__viewport";

    var wrapper = document.createElement("div");
    wrapper.className = "mermaid-panzoom";
    wrapper.tabIndex = 0;
    wrapper.setAttribute("role", "group");
    wrapper.setAttribute("aria-label", "Interactive Mermaid diagram");

    var toolbar = document.createElement("div");
    toolbar.className = "mermaid-panzoom__toolbar";

    function button(label, icon, className, handler) {
      var control = document.createElement("button");
      control.type = "button";
      control.className = "mermaid-panzoom__button " + className;
      control.setAttribute("aria-label", label);
      control.title = label;
      var iconElement = document.createElement("span");
      iconElement.className = "mermaid-panzoom__icon";
      iconElement.setAttribute("aria-hidden", "true");
      iconElement.textContent = icon;
      control.appendChild(iconElement);
      control.addEventListener("click", handler);
      return control;
    }

    var state = {
      diagram: diagram,
      scale: 1,
      x: 0,
      y: 0,
      dragging: false,
      lastX: 0,
      lastY: 0,
      pointers: new Map(),
      pinchDistance: 0,
      pinchScale: 1
    };

    state.zoomOut = button("Zoom out", "−", "mermaid-panzoom__zoom-out", function () {
      updateScale(state, state.scale - SCALE_STEP, viewport.clientWidth / 2, viewport.clientHeight / 2);
      render(state);
    });

    state.zoom = document.createElement("span");
    state.zoom.className = "mermaid-panzoom__zoom-level";
    state.zoom.setAttribute("aria-live", "polite");

    state.zoomIn = button("Zoom in", "+", "mermaid-panzoom__zoom-in", function () {
      updateScale(state, state.scale + SCALE_STEP, viewport.clientWidth / 2, viewport.clientHeight / 2);
      render(state);
    });

    var reset = button("Reset diagram view", "↺", "mermaid-panzoom__reset", function () {
      state.scale = 1;
      state.x = 0;
      state.y = 0;
      render(state);
    });
    state.reset = reset;

    var fullscreen = button("Open diagram fullscreen", "⛶", "mermaid-panzoom__fullscreen", function () {
      if (wrapper.requestFullscreen) {
        wrapper.requestFullscreen();
      }
    });

    toolbar.append(state.zoomOut, state.zoom, state.zoomIn, reset, fullscreen);
    wrapper.append(toolbar, viewport);
    originalParent.replaceChild(wrapper, diagram);
    viewport.appendChild(diagram);

    state.diagram.style.transformOrigin = "0 0";
    state.diagram.style.transition = "transform 120ms ease-out";
    render(state);

    viewport.addEventListener("wheel", function (event) {
      event.preventDefault();
      var bounds = viewport.getBoundingClientRect();
      var factor = event.deltaY < 0 ? 1 + SCALE_STEP : 1 - SCALE_STEP;
      updateScale(state, state.scale * factor, event.clientX - bounds.left, event.clientY - bounds.top);
      render(state);
    }, { passive: false });

    viewport.addEventListener("pointerdown", function (event) {
      if (event.button !== 0 || event.target.closest("button")) {
        return;
      }

      state.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
      viewport.setPointerCapture(event.pointerId);

      if (state.pointers.size === 2) {
        var pinchPoints = Array.from(state.pointers.values());
        state.pinchDistance = Math.hypot(
          pinchPoints[0].x - pinchPoints[1].x,
          pinchPoints[0].y - pinchPoints[1].y
        );
        state.pinchScale = state.scale;
        state.dragging = false;
        viewport.classList.add("is-dragging");
        return;
      }

      state.dragging = true;
      state.lastX = event.clientX;
      state.lastY = event.clientY;
      viewport.classList.add("is-dragging");
    });

    viewport.addEventListener("pointermove", function (event) {
      if (!state.pointers.has(event.pointerId)) {
        return;
      }

      state.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });

      if (state.pointers.size === 2) {
        var pinchPoints = Array.from(state.pointers.values());
        var pinchDistance = Math.hypot(
          pinchPoints[0].x - pinchPoints[1].x,
          pinchPoints[0].y - pinchPoints[1].y
        );
        var bounds = viewport.getBoundingClientRect();
        var centerX = (pinchPoints[0].x + pinchPoints[1].x) / 2 - bounds.left;
        var centerY = (pinchPoints[0].y + pinchPoints[1].y) / 2 - bounds.top;
        if (state.pinchDistance > 0) {
          updateScale(state, state.pinchScale * pinchDistance / state.pinchDistance, centerX, centerY);
        }
        render(state);
        return;
      }

      if (!state.dragging) {
        return;
      }

      state.x += event.clientX - state.lastX;
      state.y += event.clientY - state.lastY;
      state.lastX = event.clientX;
      state.lastY = event.clientY;
      render(state);
    });

    function stopDragging(event) {
      state.pointers.delete(event.pointerId);
      if (viewport.hasPointerCapture(event.pointerId)) {
        viewport.releasePointerCapture(event.pointerId);
      }

      if (state.pointers.size > 0) {
        var remaining = state.pointers.values().next().value;
        state.lastX = remaining.x;
        state.lastY = remaining.y;
        state.dragging = true;
        return;
      }

      state.dragging = false;
      viewport.classList.remove("is-dragging");
    }

    viewport.addEventListener("pointerup", stopDragging);
    viewport.addEventListener("pointercancel", stopDragging);
    wrapper.addEventListener("keydown", function (event) {
      if (event.key === "+" || event.key === "=") {
        state.zoomIn.click();
      } else if (event.key === "-" || event.key === "_") {
        state.zoomOut.click();
      } else if (event.key.toLowerCase() === "r") {
        reset.click();
      } else if (event.key.toLowerCase() === "f") {
        fullscreen.click();
      }
    });
  }

  function scan() {
    document.querySelectorAll(".mermaid:not([" + ENHANCED + "])").forEach(enhance);
  }

  function start() {
    scan();
    new MutationObserver(scan).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
}());
