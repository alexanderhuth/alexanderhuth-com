(() => {
  const buttons = Array.from(document.querySelectorAll("[data-media-filter]"));
  const monthGroups = Array.from(document.querySelectorAll("[data-media-month-group]"));

  if (!buttons.length || !monthGroups.length) {
    return;
  }

  const applyFilter = (filter) => {
    buttons.forEach((button) => {
      const isActive = button.dataset.mediaFilter === filter;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-pressed", isActive ? "true" : "false");
    });

    monthGroups.forEach((group) => {
      const rows = Array.from(group.querySelectorAll("tr[data-media-type]"));
      let visibleRows = 0;

      rows.forEach((row) => {
        const matches = filter === "all" || row.dataset.mediaType === filter;
        row.hidden = !matches;
        if (matches) {
          visibleRows += 1;
        }
      });

      group.hidden = visibleRows === 0;
    });
  };

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      applyFilter(button.dataset.mediaFilter || "all");
    });
  });

  applyFilter("all");
})();
