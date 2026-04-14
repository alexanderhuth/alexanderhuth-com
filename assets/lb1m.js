/**
 * Chart.js renderer for LB1M chart data.
 * Expects `window.chartData` to be set before this script runs.
 */
(function () {
  "use strict";

  var C = window.chartData;
  if (!C) return;

  /* ── Palette (IBCS brand colours from matplotlib originals) ──────── */
  var PRIMARY = "#4A9FD4";
  var ACCENT1 = "#F5A623";
  var ACCENT2 = "#4CAF50";
  var MUTED   = "#555E6B";
  var TEXT    = "#FFFFFF";

  /* ── Helpers ─────────────────────────────────────────────────────── */

  function stripePattern(color, size) {
    var s = size || 6;
    var c = document.createElement("canvas");
    c.width = s; c.height = s;
    var ctx = c.getContext("2d");
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, s); ctx.lineTo(s, 0);
    ctx.stroke();
    return ctx.createPattern(c, "repeat");
  }

  var STRIPE_ORANGE = null;
  function getStripe() {
    if (!STRIPE_ORANGE) STRIPE_ORANGE = stripePattern(ACCENT1);
    return STRIPE_ORANGE;
  }

  var MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

  function applyDefaults() {
    Chart.defaults.color = TEXT;
    Chart.defaults.font.family = "'Helvetica Neue', Arial, sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.plugins.legend.display = false;
    Chart.defaults.plugins.tooltip.enabled = true;
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = true;
    Chart.register(headroomPlugin);
  }

  function hiddenY(extra) {
    var base = { display: false, grid: { display: false } };
    if (extra) Object.assign(base, extra);
    return base;
  }

  /** Shared horizontal bar chart builder. All hbar charts use this for consistency. */
  function buildHbar(canvas, labels, values, labelTexts, opts) {
    opts = opts || {};
    var bestIdx = 0;
    if (opts.highlightMin) {
      values.forEach(function (v, i) { if (v < values[bestIdx]) bestIdx = i; });
    } else {
      values.forEach(function (v, i) { if (v > values[bestIdx]) bestIdx = i; });
    }
    var colors = values.map(function (_, i) { return i === bestIdx ? ACCENT2 : PRIMARY; });
    var labelItems = labelTexts.map(function (t, i) { return { dsi: 0, idx: i, text: t }; });
    var xConfig = { display: false, grid: { display: false }, _headroom: 0.25 };
    if (opts.xMin !== undefined) xConfig.display = true;
    if (opts.xMin !== undefined) xConfig.min = opts.xMin;
    if (opts.xMax !== undefined) xConfig.max = opts.xMax;
    if (opts.xDisplay) {
      xConfig.display = true;
      xConfig.border = { color: TEXT, width: 1 };
      xConfig.ticks = { color: TEXT, font: { size: 10 } };
      if (opts.xTickCallback) xConfig.ticks.callback = opts.xTickCallback;
    }
    var chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [{ data: values, backgroundColor: colors, borderWidth: 0, barPercentage: 0.82, categoryPercentage: 0.82 }],
      },
      options: {
        indexAxis: "y",
        aspectRatio: values.length <= 5 ? 2.2 : 1.6,
        layout: { padding: { left: 8, bottom: opts.xDisplay ? 8 : 0 } },
        plugins: {
          tooltip: { callbacks: { label: function (ctx) { return labelItems[ctx.dataIndex].text; } } },
        },
        scales: {
          x: xConfig,
          y: {
            grid: { display: false },
            border: { display: false },
            ticks: {
              color: TEXT,
              font: { size: 11 },
              callback: function (value, index) {
                var label = this.getLabelForValue(value);
                var maxChars = Math.floor((this.chart.width * 0.3 - 8) / 6.5);
                if (label.length > maxChars) return label.substring(0, maxChars - 1) + "\u2026";
                return label;
              },
            },
            afterFit: function (axis) { axis.width = axis.chart.width * 0.3; },
          },
        },
      },
      plugins: [hbarLabelPlugin],
    });
    chart.config._lb1mHbarLabels = labelItems;
    chart.update();
    return chart;
  }

  function bottomAxis(extra) {
    var base = {
      grid: { display: false },
      border: { color: TEXT, width: 1 },
      ticks: { color: TEXT, font: { size: 11 } },
    };
    if (extra) Object.assign(base, extra);
    return base;
  }

  /* ── Plugins ─────────────────────────────────────────────────────── */

  /** Draw value labels above/beside bars. */
  var datalabelPlugin = {
    id: "lb1mLabels",
    afterDatasetsDraw: function (chart) {
      var meta = chart.config._lb1mLabels;
      if (!meta) return;
      var ctx = chart.ctx;
      ctx.save();
      ctx.font = "11px 'Helvetica Neue', Arial, sans-serif";
      ctx.textBaseline = "bottom";
      meta.forEach(function (item) {
        if (!item) return;
        var dsMeta = chart.getDatasetMeta(item.dsi);
        if (!dsMeta || !dsMeta.data[item.idx]) return;
        var el = dsMeta.data[item.idx];
        ctx.fillStyle = item.color || TEXT;
        ctx.textAlign = item.align || "center";
        var x = item.xOff ? el.x + item.xOff : el.x;
        var y;
        if (item.useBarCenter && el.base !== undefined) {
          y = (el.y + el.base) / 2;
        } else {
          y = item.yOff !== undefined ? el.y + item.yOff : el.y - 6;
        }
        if (item.baseline) ctx.textBaseline = item.baseline;
        ctx.fillText(item.text, x, y);
        ctx.textBaseline = "bottom";
      });
      ctx.restore();
    },
  };

  /** Draw value labels for horizontal bars (to the right). */
  var hbarLabelPlugin = {
    id: "lb1mHbarLabels",
    afterDatasetsDraw: function (chart) {
      var meta = chart.config._lb1mHbarLabels;
      if (!meta) return;
      var ctx = chart.ctx;
      ctx.save();
      ctx.font = "11px 'Helvetica Neue', Arial, sans-serif";
      ctx.textBaseline = "middle";
      ctx.fillStyle = TEXT;
      meta.forEach(function (item) {
        var el = chart.getDatasetMeta(item.dsi).data[item.idx];
        if (!el) return;
        ctx.textAlign = "left";
        ctx.fillText(item.text, el.x + 6, el.y);
      });
      ctx.restore();
    },
  };

  /** Draw center text inside doughnut charts (afterDatasetsDraw = after arcs, before tooltip). */
  var doughnutCenterPlugin = {
    id: "lb1mDoughnutCenter",
    afterDatasetsDraw: function (chart) {
      var meta = chart.config._lb1mCenter;
      if (!meta) return;
      var ctx = chart.ctx;
      var area = chart.chartArea;
      var cx = (area.left + area.right) / 2;
      var cy = (area.top + area.bottom) / 2;
      ctx.save();
      ctx.textAlign = "center";
      ctx.fillStyle = TEXT;
      ctx.font = "bold 18px 'Helvetica Neue', Arial, sans-serif";
      ctx.fillText(meta.count, cx, cy);
      ctx.fillStyle = "rgba(255,255,255,0.65)";
      ctx.font = "11px 'Helvetica Neue', Arial, sans-serif";
      ctx.fillText(meta.pct, cx, cy + 18);
      ctx.restore();
    },
  };

  /** Show persistent tooltip on the highlighted bubble after render. */
  var bubblePersistentTooltipPlugin = {
    id: "lb1mBubblePersist",
    afterRender: function (chart) {
      var meta = chart.config._lb1mBubblePersist;
      if (!meta || chart._lb1mTooltipShown) return;
      chart._lb1mTooltipShown = true;
      var tooltip = chart.tooltip;
      var dsIndex = meta.dsIndex || 0;
      var idx = meta.bestIdx;
      var el = chart.getDatasetMeta(dsIndex).data[idx];
      if (!el) return;
      tooltip.setActiveElements([{ datasetIndex: dsIndex, index: idx }], { x: el.x, y: el.y });
      chart.update("none");
    },
  };

  /** Draw a horizontal zero-line across bar charts. */
  var zeroLinePlugin = {
    id: "lb1mZeroLine",
    afterDatasetsDraw: function (chart) {
      if (!chart.config._lb1mZeroLine) return;
      var yScale = chart.scales.y;
      if (!yScale) return;
      var yPixel = yScale.getPixelForValue(0);
      var ctx = chart.ctx;
      ctx.save();
      ctx.strokeStyle = TEXT;
      ctx.lineWidth = 0.8;
      ctx.globalAlpha = 0.5;
      ctx.beginPath();
      ctx.moveTo(chart.chartArea.left, yPixel);
      ctx.lineTo(chart.chartArea.right, yPixel);
      ctx.stroke();
      ctx.restore();
    },
  };

  /** Add top-only headroom to a scale for data labels (no bottom padding). */
  function addHeadroom(scaleOpts, pct) {
    // Chart.js 'grace' adds padding on BOTH ends. Instead, we use afterBuildTicks
    // to nudge suggestedMax upward based on the data range.
    var origPct = pct || 0.15;
    return Object.assign({}, scaleOpts, { _headroom: origPct });
  }

  var headroomPlugin = {
    id: "lb1mHeadroom",
    beforeLayout: function (chart) {
      ["x", "y"].forEach(function (axis) {
        var opts = chart.options.scales[axis];
        if (!opts || !opts._headroom) return;
        var pct = opts._headroom;
        // Find data max for this axis
        var max = -Infinity;
        chart.data.datasets.forEach(function (ds) {
          (ds.data || []).forEach(function (v) {
            var val;
            if (typeof v === "number") val = v;
            else if (v && typeof v === "object") val = axis === "x" ? v.x : v.y;
            if (typeof val === "number" && val > max) max = val;
          });
        });
        if (max !== -Infinity && isFinite(max)) {
          opts.suggestedMax = max * (1 + pct);
        }
      });
    },
  };

  /* ── Chart renderers ─────────────────────────────────────────────── */

  /* 1. Monthly additions — vertical bar chart */
  function renderMonthlyAdditions(canvas, d) {
    var colors = d.values.map(function (_, i) {
      if (i === d.maxIndex) return ACCENT2;
      if (i === d.currentMonthIndex) return ACCENT1;
      return PRIMARY;
    });
    var chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.labels,
        datasets: [{
          data: d.values,
          backgroundColor: colors,
          borderWidth: 0,
          barPercentage: 0.82,
          categoryPercentage: 0.82,
        }],
      },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        scales: {
          y: hiddenY({ _headroom: 0.15 }),
          x: bottomAxis({
            ticks: {
              color: TEXT, font: { size: 10 },
              maxRotation: 0, autoSkip: false,
              callback: function (val, idx) {
                var label = d.labels[idx];
                if (!label) return "";
                var parts = label.split("-");
                var m = parseInt(parts[1], 10);
                if (m === 1 && idx > 0) return MONTHS[0] + " " + parts[0];
                return "";
              },
            },
          }),
        },
        plugins: {
          tooltip: {
            callbacks: {
              title: function(items) {
                var label = items[0].label || '';
                var parts = label.split('-');
                return MONTHS[parseInt(parts[1],10)-1] + ' ' + parts[0];
              }
            }
          }
        }
      },
      plugins: [datalabelPlugin],
    });
    var lbls = [{
      dsi: 0, idx: d.maxIndex,
      text: String(d.values[d.maxIndex]),
      color: TEXT,
    }];
    if (d.currentMonthIndex !== d.maxIndex) {
      lbls.push({
        dsi: 0, idx: d.currentMonthIndex,
        text: String(d.values[d.currentMonthIndex]),
        color: TEXT,
      });
    }
    chart.config._lb1mLabels = lbls;
    chart.update();
  }

  /* 2. Cumulative additions — line chart with time axis */
  function renderCumulativeAdditions(canvas, d) {
    // Parse dates into Date objects for proper time axis
    var timeData = d.dates.map(function (dateStr, i) {
      return { x: dateStr.substring(0, 10), y: d.values[i] };
    });
    var chart = new Chart(canvas, {
      type: "line",
      data: {
        datasets: [{
          data: timeData,
          borderColor: PRIMARY,
          borderWidth: 2.5,
          pointRadius: 0,
          fill: false,
          tension: 0,
        }],
      },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { top: 20, left: 16, right: 30, bottom: 8 } },
        scales: {
          y: hiddenY({ beginAtZero: true }),
          x: {
            type: "time",
            time: { unit: "year", displayFormats: { year: "MMM yyyy" } },
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 10 }, maxRotation: 0 },
          },
        },
      },
      plugins: [datalabelPlugin],
    });
    // Generate annotations for each Jan 1
    var labelItems = [];
    var seenYears = {};
    timeData.forEach(function(pt, i) {
      var dateStr = pt.x;
      var month = parseInt(dateStr.substring(5,7), 10);
      var day = parseInt(dateStr.substring(8,10), 10);
      var year = parseInt(dateStr.substring(0,4), 10);
      // Find the first data point on or after Jan 1 of each year (skip first year)
      if (!seenYears[year] && year > parseInt(timeData[0].x.substring(0,4), 10)) {
        seenYears[year] = true;
        labelItems.push({
          dsi: 0, idx: i,
          text: pt.y.toLocaleString(),
          color: TEXT, yOff: -14,
        });
      }
    });
    // Also add the very last point
    var lastIdx = timeData.length - 1;
    var lastYear = parseInt(timeData[lastIdx].x.substring(0,4), 10);
    if (!seenYears[lastYear] || true) {
      labelItems.push({
        dsi: 0, idx: lastIdx,
        text: timeData[lastIdx].y.toLocaleString(),
        color: TEXT, yOff: -14,
      });
    }
    chart.config._lb1mLabels = labelItems;
    chart.update();
  }

  /* 3. Yearly additions — stacked bar with projection */
  function renderYearlyAdditions(canvas, d) {
    var colors = d.values.map(function (_, i) {
      if (d.partialYear && i === d.partialYear.index) return ACCENT1;
      if (i === d.maxIndex) return ACCENT2;
      return PRIMARY;
    });
    var datasets = [{
      data: d.values.map(function (v, i) {
        return d.partialYear && i === d.partialYear.index ? d.partialYear.actual : v;
      }),
      backgroundColor: colors,
      borderWidth: 0,
      barPercentage: 0.82,
    }];
    if (d.partialYear) {
      var ext = d.values.map(function () { return 0; });
      ext[d.partialYear.index] = d.partialYear.projected - d.partialYear.actual;
      datasets.push({
        data: ext,
        backgroundColor: getStripe(),
        borderColor: ACCENT1,
        borderWidth: 1,
        barPercentage: 0.82,
      });
    }
    var labelItems = [];
    d.values.forEach(function (v, i) {
      if (d.partialYear && i === d.partialYear.index) {
        // Actual count — centered inside the orange bar
        labelItems.push({
          dsi: 0, idx: i,
          text: String(d.partialYear.actual),
          color: TEXT, useBarCenter: true, baseline: "middle",
        });
        // Projected total above the hatched extension
        labelItems.push({
          dsi: 1, idx: i,
          text: "~" + d.partialYear.projected,
          color: ACCENT1, yOff: -8,
        });
      } else {
        labelItems.push({ dsi: 0, idx: i, text: String(v), color: TEXT });
      }
    });
    var chart = new Chart(canvas, {
      type: "bar",
      data: { labels: d.labels, datasets: datasets },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 20 } },
        scales: {
          y: Object.assign(hiddenY({ _headroom: 0.1 }), { stacked: true }),
          x: bottomAxis({ stacked: true }),
        },
      },
      plugins: [datalabelPlugin],
    });
    chart.config._lb1mLabels = labelItems;
    chart.update();
  }

  /* 4. YoY growth — bar chart with zero-line and outlier handling */
  function renderYoyGrowth(canvas, d) {
    var displayVals = d.values.map(function (v, i) {
      return d.outlier && i === d.outlier.index ? d.outlier.cap : v;
    });
    var bgColors = d.values.map(function (_, i) {
      if (d.projectedIndex !== null && i === d.projectedIndex) return getStripe();
      return PRIMARY;
    });
    var borderColors = d.values.map(function (_, i) {
      if (d.projectedIndex !== null && i === d.projectedIndex) return ACCENT1;
      return "transparent";
    });
    var labelItems = d.values.map(function (v, i) {
      var text;
      if (d.outlier && i === d.outlier.index) {
        text = "+" + Math.round(d.outlier.actual) + "%";
      } else {
        text = (v >= 0 ? "+" : "") + Math.round(v) + "%";
      }
      return {
        dsi: 0, idx: i, text: text, color: TEXT,
        yOff: v >= 0 ? -8 : 14,
      };
    });
    var chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.labels,
        datasets: [{
          data: displayVals,
          backgroundColor: bgColors,
          borderColor: borderColors,
          borderWidth: 1,
          barPercentage: 0.7,
        }],
      },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        scales: {
          y: hiddenY({ _headroom: 0.15 }),
          x: bottomAxis(),
        },
      },
      plugins: [datalabelPlugin, zeroLinePlugin],
    });
    chart.config._lb1mLabels = labelItems;
    chart.config._lb1mZeroLine = true;
    // Add off-scale text for outlier
    if (d.outlier) {
      var origAfter = chart.config.plugins.find(function (p) { return p.id === "lb1mLabels"; });
      var offScalePlugin = {
        id: "lb1mOffScale",
        afterDatasetsDraw: function (ch) {
          if (!d.outlier) return;
          var el = ch.getDatasetMeta(0).data[d.outlier.index];
          if (!el) return;
          var ctx = ch.ctx;
          ctx.save();
          ctx.fillStyle = TEXT;
          ctx.globalAlpha = 0.7;
          ctx.font = "10px 'Helvetica Neue', Arial, sans-serif";
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.translate(el.x, (el.y + el.base) / 2);
          ctx.rotate(-Math.PI / 2);
          ctx.fillText("\u2191 off-scale", 0, 0);
          ctx.restore();
        },
      };
      chart.config.plugins.push(offScalePlugin);
    }
    chart.update();
  }

  /* 5. Quarterly additions — per-year grid layout (3 cols) */
  function renderQuarterlyAdditions(canvas, d) {
    var container = document.createElement("div");
    container.className = "chart-quarterly-grid";
    canvas.parentNode.replaceChild(container, canvas);

    var maxTotal = Math.max.apply(null, d.totals);
    var qNames = ["Q1", "Q2", "Q3", "Q4"];

    d.years.forEach(function (yr, yi) {
      var cell = document.createElement("div");
      cell.className = "chart-quarterly-cell";
      var mc = document.createElement("canvas");
      cell.appendChild(mc);
      container.appendChild(cell);

      var quarters = d.quarters[yi];
      var predicted = d.predicted[yi];
      var total = d.totals[yi];
      var isPartial = predicted.some(function (p) { return p; });

      // 5 bars: Q1, Q2, Q3, Q4, Full year
      var barLabels = qNames.concat(["Year"]);

      // For partial year: split current quarter and full year into solid + forecast
      var actualValues = quarters.slice();
      var forecastValues = quarters.map(function () { return 0; });
      var cqi = d.currentQuarterIndex;
      var cqa = d.currentQuarterActual || 0;

      if (isPartial) {
        quarters.forEach(function (q, qi) {
          if (predicted[qi]) {
            if (qi === cqi) {
              // Current quarter: split into actual + forecast
              actualValues[qi] = cqa;
              forecastValues[qi] = q - cqa;
            } else {
              // Fully forecast quarter
              actualValues[qi] = 0;
              forecastValues[qi] = q;
            }
          }
        });
      }

      // Full year bar: actual = sum of all actual portions
      var actualFullYear = 0;
      actualValues.forEach(function (v) { actualFullYear += v; });
      var forecastFullYear = isPartial ? (total - actualFullYear) : 0;

      actualValues.push(isPartial ? actualFullYear : total);
      forecastValues.push(forecastFullYear);

      var datasets = [
        {
          data: actualValues,
          backgroundColor: actualValues.map(function (_, bi) {
            if (bi === 4) return isPartial ? ACCENT1 : MUTED; // Full year bar
            if (isPartial && predicted[bi] && bi === cqi) return ACCENT1; // Current quarter actual = orange
            return PRIMARY;
          }),
          borderColor: "transparent",
          borderWidth: 0,
          barPercentage: function (ctx) {
            return ctx.dataIndex === 4 ? 0.95 : 0.6;
          },
        },
        {
          data: forecastValues,
          backgroundColor: getStripe(),
          borderColor: forecastValues.map(function (v) { return v > 0 ? ACCENT1 : "transparent"; }),
          borderWidth: 1,
          barPercentage: function (ctx) {
            return ctx.dataIndex === 4 ? 0.95 : 0.6;
          },
        }
      ];

      var labelItems = [];
      // Label each bar with its TOTAL value (actual + forecast)
      for (var bi = 0; bi < actualValues.length; bi++) {
        var barTotal = actualValues[bi] + forecastValues[bi];
        if (barTotal > 0) {
          // Put label above the top of the stack (forecast dataset if has forecast, actual otherwise)
          var dsi = forecastValues[bi] > 0 ? 1 : 0;
          labelItems.push({ dsi: dsi, idx: bi, text: String(barTotal), color: TEXT, yOff: -6 });
        }
      }
      // For partial year Full Year bar: also show actual count centered inside the solid portion
      if (isPartial && actualFullYear > 0) {
        labelItems.push({ dsi: 0, idx: 4, text: String(actualFullYear), color: TEXT, useBarCenter: true, baseline: "middle" });
      }

      var chart = new Chart(mc, {
        type: "bar",
        data: {
          labels: barLabels,
          datasets: datasets,
        },
        options: {
          aspectRatio: 1.0,
          scales: {
            y: Object.assign(hiddenY(), { max: maxTotal * 1.25, beginAtZero: true, stacked: true }),
            x: {
              grid: { display: false },
              border: { display: false },
              ticks: { color: TEXT, font: { size: 9 }, maxRotation: 0 },
              stacked: true,
            },
          },
          plugins: {
            title: {
              display: true,
              text: String(yr),
              color: TEXT,
              font: { size: 13 },
              padding: { bottom: 4 },
            },
          },
        },
        plugins: [datalabelPlugin, zeroLinePlugin],
      });
      chart.config._lb1mLabels = labelItems;
      chart.config._lb1mZeroLine = true;
      chart.update();
    });
  }

  /* 6. Films by decade — vertical bar chart */
  function renderFilmsByDecade(canvas, d) {
    var colors = d.values.map(function (_, i) {
      if (i === d.maxIndex) return ACCENT2;
      if (i === d.currentDecadeIndex) return ACCENT1;
      return PRIMARY;
    });
    var labelItems = d.values.map(function (v, i) {
      return { dsi: 0, idx: i, text: String(v), color: TEXT };
    });
    var chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.labels,
        datasets: [{ data: d.values, backgroundColor: colors, borderWidth: 0, barPercentage: 0.82, categoryPercentage: 0.82 }],
      },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { left: 16, right: 16, bottom: 8 } },
        scales: { y: hiddenY({ _headroom: 0.15 }), x: bottomAxis() },
      },
      plugins: [datalabelPlugin],
    });
    chart.config._lb1mLabels = labelItems;
    chart.update();
  }

  /* 7. Films by year — vertical bar chart with continuous year axis */
  function renderFilmsByYear(canvas, d) {
    // Fill gaps: create a continuous range from first to last year
    var minYear = d.labels[0];
    var maxYear = d.labels[d.labels.length - 1];
    var yearMap = {};
    d.labels.forEach(function (yr, i) { yearMap[yr] = d.values[i]; });

    var fullLabels = [];
    var fullValues = [];
    for (var yr = minYear; yr <= maxYear; yr++) {
      fullLabels.push(yr);
      fullValues.push(yearMap[yr] || 0);
    }

    // Find max and last indices in the full arrays
    var maxIdx = 0;
    var maxVal = 0;
    var lastYear = d.labels[d.labels.length - 1];
    fullValues.forEach(function (v, i) {
      if (fullLabels[i] !== lastYear && v > maxVal) { maxVal = v; maxIdx = i; }
    });
    var lastIdx = fullLabels.indexOf(lastYear);

    var colors = fullValues.map(function (_, i) {
      if (i === maxIdx) return ACCENT2;
      if (i === lastIdx) return ACCENT1;
      return PRIMARY;
    });

    var labelItems = [{ dsi: 0, idx: maxIdx, text: String(maxVal), color: TEXT }];
    if (lastIdx !== maxIdx) {
      labelItems.push({ dsi: 0, idx: lastIdx, text: String(fullValues[lastIdx]), color: TEXT });
    }

    var chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: fullLabels,
        datasets: [{
          data: fullValues, backgroundColor: colors, borderWidth: 0,
          barPercentage: 0.82, categoryPercentage: 0.9,
        }],
      },
      options: {
        aspectRatio: 2.2,
        layout: { padding: { left: 16, right: 16, bottom: 8 } },
        scales: {
          y: hiddenY({ _headroom: 0.15 }),
          x: bottomAxis({
            ticks: {
              color: TEXT, font: { size: 10 },
              maxRotation: 0, autoSkip: false,
              callback: function (val, idx) {
                var yr = fullLabels[idx];
                return yr % 10 === 0 ? String(yr) : "";
              },
            },
          }),
        },
      },
      plugins: [datalabelPlugin],
    });
    chart.config._lb1mLabels = labelItems;
    chart.update();
  }

  /* 8. Top genres — horizontal bar chart */
  function renderTopGenres(canvas, d) {
    buildHbar(canvas, d.labels, d.values, d.values.map(function (v) { return v + " films"; }));
  }

  function renderTopCountries(canvas, d) {
    buildHbar(canvas, d.labels, d.values, d.values.map(function (v) { return v + " films"; }));
  }

  /* 9. Film segments — 4 equal doughnut charts with title above */
  function renderFilmSegments(canvas, d) {
    var container = document.createElement("div");
    container.className = "chart-segments";
    canvas.parentNode.replaceChild(container, canvas);

    var titleOverrides = {
      "Films in the Letterboxd Top 500": "Letterboxd Top 500",
      "Films in a Franchise/Series": "Part of Collection",
    };

    d.segments.forEach(function (seg) {
      var wrapper = document.createElement("div");
      wrapper.className = "chart-segment-item";
      var title = document.createElement("span");
      title.className = "chart-segment-title";
      title.textContent = titleOverrides[seg.label] || seg.label;
      var canvasWrap = document.createElement("div");
      canvasWrap.className = "chart-segment-canvas";
      var miniCanvas = document.createElement("canvas");
      canvasWrap.appendChild(miniCanvas);
      wrapper.appendChild(title);
      wrapper.appendChild(canvasWrap);
      container.appendChild(wrapper);

      var pct = seg.count / d.total;
      var chart = new Chart(miniCanvas, {
        type: "doughnut",
        data: {
          datasets: [{
            data: [pct, 1 - pct],
            backgroundColor: [PRIMARY, MUTED],
            borderWidth: 0,
            cutout: "72%",
            rotation: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: true,
          plugins: {
            legend: { display: false },
            tooltip: {
              enabled: true,
              callbacks: {
                label: function(ctx) {
                  if (ctx.dataIndex === 0) {
                    return seg.count + ' of ' + d.total + ' (' + Math.round(pct*100) + '%)';
                  }
                  return '';
                }
              }
            },
          },
        },
        plugins: [doughnutCenterPlugin],
      });
      chart.config._lb1mCenter = {
        count: String(seg.count),
        pct: Math.round(pct * 100) + "%",
      };
      chart.update();
    });
  }

  /* 10–11. Bubble/scatter charts (fans_per_watch, heartrate) */
  function renderBubbleChart(canvas, d, xLabel) {
    var maxSize = 0;
    var bestIdx = 0;
    d.points.forEach(function(p, i) { if (p.size > maxSize) { maxSize = p.size; bestIdx = i; } });
    if (maxSize === 0) maxSize = 1;

    // Two datasets: gray bubbles (background), then green highlight (foreground)
    var grayData = [];
    var bestBubble = null;
    d.points.forEach(function (p, i) {
      var b = { x: p.x, y: p.y, r: 3 + Math.sqrt(p.size / maxSize) * 7 };
      if (i === bestIdx) {
        bestBubble = b;
      } else {
        grayData.push(b);
      }
    });

    // Increase green bubble radius to stand out
    if (bestBubble) bestBubble.r = Math.max(bestBubble.r, 10);
    var datasets = [
      { data: grayData, backgroundColor: MUTED, borderWidth: 0, order: 2 },
      { data: bestBubble ? [bestBubble] : [], backgroundColor: ACCENT2, borderWidth: 0, order: 1 },
    ];

    // Build a title lookup for gray dataset (indices shifted because bestIdx was removed)
    var grayTitles = [];
    d.points.forEach(function(p, i) { if (i !== bestIdx) grayTitles.push(p.title); });
    var bestPoint = d.points[bestIdx];

    var chart = new Chart(canvas, {
      type: "bubble",
      data: { datasets: datasets },
      options: {
        aspectRatio: 2.0,
        layout: { padding: { bottom: 8 } },
        scales: {
          y: hiddenY(),
          x: bottomAxis({
            ticks: {
              color: TEXT, font: { size: 10 },
              callback: function (v) { return xLabel ? v + xLabel : v; },
            },
          }),
        },
        plugins: {
          tooltip: {
            caretSize: 6,
            position: "nearest",
            backgroundColor: function (ctx) {
              var item = ctx.tooltip.dataPoints && ctx.tooltip.dataPoints[0];
              return item && item.datasetIndex === 1 ? ACCENT2 : "rgba(0,0,0,0.8)";
            },
            callbacks: {
              title: function (items) {
                var item = items[0];
                if (item.datasetIndex === 0) return grayTitles[item.dataIndex] || "";
                if (item.datasetIndex === 1) return bestPoint ? bestPoint.title : "";
                return "";
              },
              label: function (ctx) {
                if (ctx.datasetIndex === 1 && d.best && d.best.label) return d.best.label;
                return null;
              },
            },
          },
        },
      },
      plugins: [bubblePersistentTooltipPlugin],
    });
    // Persistent tooltip targets dataset 1 (the green highlight), index 0
    chart.config._lb1mBubblePersist = { dsIndex: 1, bestIdx: 0 };
    chart.update();
  }

  function renderFansPerWatch(canvas, d) {
    renderBubbleChart(canvas, d, "");
  }

  function renderHeartrateVsWatches(canvas, d) {
    renderBubbleChart(canvas, d, "%");
  }

  /* 12. Fastest films — horizontal bar chart */
  function renderFastestFilms(canvas, d) {
    buildHbar(canvas, d.labels, d.values, d.values.map(function (v) { return v + " days"; }), { highlightMin: true });
  }

  function renderFastestFilmsTheatrical(canvas, d) {
    buildHbar(canvas, d.labels, d.values, d.values.map(function (v) { return v + " days"; }), { highlightMin: true });
  }

  function renderHighestLowestRated(canvas, d) {
    var films = d.highest;
    var labels = films.map(function (f) { return f.title; });
    var values = films.map(function (f) { return f.rating; });
    var texts = values.map(function (v) { return v.toFixed(2) + " stars"; });
    buildHbar(canvas, labels, values, texts, { xMin: 4, xMax: 5, xDisplay: true, xTickCallback: function (v) { return v.toFixed(1); } });
  }

  function renderTopFanRates(canvas, d) {
    var labels = d.map(function (f) { return f.title; });
    var values = d.map(function (f) { return f.value; });
    var texts = values.map(function (v) {
      return (v % 1 ? v.toFixed(v >= 10 ? 1 : 2) : String(v)) + "%";
    });
    buildHbar(canvas, labels, values, texts, { xMin: 0, xMax: 10, xDisplay: true, xTickCallback: function (v) { return v + "%"; } });
  }

  function renderTopLikeRates(canvas, d) {
    var labels = d.map(function (f) { return f.title; });
    var values = d.map(function (f) { return f.value; });
    var texts = values.map(function (v) {
      return (v % 1 ? v.toFixed(v >= 10 ? 1 : 2) : String(v)) + "%";
    });
    buildHbar(canvas, labels, values, texts, { xMin: 0, xMax: 60, xDisplay: true, xTickCallback: function (v) { return v + "%"; } });
  }

  /* ── Router ──────────────────────────────────────────────────────── */

  var renderers = {
    monthly_additions: renderMonthlyAdditions,
    cumulative_additions: renderCumulativeAdditions,
    yearly_additions: renderYearlyAdditions,
    yoy_growth: renderYoyGrowth,
    quarterly_additions: renderQuarterlyAdditions,
    films_by_decade: renderFilmsByDecade,
    films_by_year: renderFilmsByYear,
    top_genres: renderTopGenres,
    top_countries: renderTopCountries,
    film_segments: renderFilmSegments,
    fans_per_watch: renderFansPerWatch,
    heartrate_vs_watches: renderHeartrateVsWatches,
    fastest_films: renderFastestFilms,
    fastest_films_theatrical: renderFastestFilmsTheatrical,
    highest_lowest_rated: renderHighestLowestRated,
    top_fan_rates: renderTopFanRates,
    top_like_rates: renderTopLikeRates,
  };

  /* ── Init ────────────────────────────────────────────────────────── */

  function init() {
    applyDefaults();
    document.querySelectorAll("canvas[data-chart]").forEach(function (canvas) {
      var key = canvas.getAttribute("data-chart");
      var renderer = renderers[key];
      if (renderer && C[key]) {
        renderer(canvas, C[key]);
      }
    });
  }

  function tryInit() {
    if (typeof Chart === "undefined") {
      setTimeout(tryInit, 50);
      return;
    }
    init();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", tryInit);
  } else {
    tryInit();
  }
})();
