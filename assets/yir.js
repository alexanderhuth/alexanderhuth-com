(function() {
  "use strict";

  var PRIMARY = "#4A9FD4";
  var ACCENT1 = "#F5A623";
  var ACCENT2 = "#4CAF50";
  var MUTED = "#555E6B";
  var TEXT = "#FFFFFF";

  var D = window.yirData || {};

  // Format millions helper
  function fmtM(v) {
    if (v >= 1000) return (v / 1000).toFixed(1) + "B";
    if (v >= 10) return Math.round(v) + "M";
    if (v >= 1) return v.toFixed(1) + "M";
    return v.toFixed(2) + "M";
  }

  // Compute suggested max with headroom
  function withHeadroom(values, pct) {
    var max = Math.max.apply(null, values.filter(function(v) { return v !== null; }));
    return max * (1 + (pct || 0.15));
  }

  // Custom plugin for data labels
  var labelPlugin = {
    id: "yirLabels",
    afterDatasetsDraw: function(chart) {
      var items = chart.config._labels;
      if (!items) return;
      var ctx = chart.ctx;
      ctx.save();
      ctx.font = "11px 'Helvetica Neue', Arial, sans-serif";
      ctx.textBaseline = "bottom";
      items.forEach(function(item) {
        if (!item) return;
        var el = chart.getDatasetMeta(item.dsi).data[item.idx];
        if (!el) return;
        ctx.fillStyle = item.color || TEXT;
        ctx.textAlign = item.align || "center";
        var x = el.x;
        var y = item.yOff !== undefined ? el.y + item.yOff : el.y - 6;
        ctx.fillText(item.text, x, y);
      });
      ctx.restore();
    }
  };

  // Zero line plugin
  var zeroLinePlugin = {
    id: "yirZeroLine",
    afterDatasetsDraw: function(chart) {
      var yAxis = chart.scales.y;
      var zeroY = yAxis.getPixelForValue(0);
      var ctx = chart.ctx;
      ctx.save();
      ctx.strokeStyle = "rgba(255, 255, 255, 0.5)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(chart.chartArea.left, zeroY);
      ctx.lineTo(chart.chartArea.right, zeroY);
      ctx.stroke();
      ctx.restore();
    }
  };

  // CAGR arrow plugin
  var cagrPlugin = {
    id: "yirCagr",
    afterDatasetsDraw: function(chart) {
      var cd = chart.config._cagrData;
      if (!cd) return;
      var meta = chart.getDatasetMeta(0);
      var first = meta.data[0];
      var last = meta.data[meta.data.length - 1];
      if (!first || !last) return;
      var ctx = chart.ctx;
      var offset = cd.offset || 0;
      var x1 = first.x;
      var y1 = first.y - offset;
      var x2 = last.x;
      var y2 = last.y - offset;
      ctx.save();
      // Line from first bar base to last bar top
      ctx.strokeStyle = ACCENT1;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
      // Arrowhead
      var angle = Math.atan2(y2 - y1, x2 - x1);
      ctx.fillStyle = ACCENT1;
      ctx.beginPath();
      ctx.moveTo(x2, y2);
      ctx.lineTo(x2 - 10 * Math.cos(angle - Math.PI / 6), y2 - 10 * Math.sin(angle - Math.PI / 6));
      ctx.lineTo(x2 - 10 * Math.cos(angle + Math.PI / 6), y2 - 10 * Math.sin(angle + Math.PI / 6));
      ctx.closePath();
      ctx.fill();
      // Badge at midpoint
      var mx = (x1 + x2) / 2;
      var my = (y1 + y2) / 2;
      var text = cd.cagr + "%";
      ctx.font = "bold 12px 'Helvetica Neue', Arial, sans-serif";
      var tw = ctx.measureText(text).width;
      ctx.fillStyle = ACCENT1;
      ctx.beginPath();
      ctx.roundRect(mx - tw / 2 - 6, my - 11, tw + 12, 22, 3);
      ctx.fill();
      ctx.fillStyle = TEXT;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(text, mx, my);
      ctx.restore();
    }
  };

  // End labels plugin for indexed_growth
  var endLabelsPlugin = {
    id: "yirEndLabels",
    afterDatasetsDraw: function(chart) {
      var ctx = chart.ctx;
      ctx.save();
      ctx.font = "bold 12px 'Helvetica Neue', Arial, sans-serif";
      ctx.textAlign = "right";
      ctx.textBaseline = "bottom";
      chart.data.datasets.forEach(function(dataset, dsi) {
        if (dataset.borderColor !== ACCENT2) return;
        var lastVal = dataset.data[dataset.data.length - 1];
        if (lastVal === null || lastVal === undefined) return;
        var lastIdx = dataset.data.length - 1;
        var meta = chart.getDatasetMeta(dsi);
        var el = meta.data[lastIdx];
        if (!el) return;
        var label = dataset.label + ": " + lastVal.toFixed(0) + "x";
        ctx.fillStyle = TEXT;
        ctx.fillText(label, el.x, el.y - 10);
      });
      ctx.restore();
    }
  };

  var renderers = {};

  // 1. Films Watched Per Year
  renderers.films_watched_per_year = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : d.values.indexOf(Math.max.apply(null, d.values));
    var colors = d.values.map(function(_, i) {
      return i === peakIndex ? ACCENT2 : PRIMARY;
    });
    var lastIdx = d.values.length - 1;
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === 0 || i === peakIndex || i === lastIdx) {
        labels.push({ dsi: 0, idx: i, text: fmtM(v), color: TEXT });
      }
    });
    var _c = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          backgroundColor: colors,
          barPercentage: 0.82,
          categoryPercentage: 0.82
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            beginAtZero: true,
            suggestedMax: withHeadroom(d.values, 0.08)
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  // 2. Cumulative Films Watched
  renderers.cumulative_films_watched = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var lastIdx = d.values.length - 1;
    var lastVal = d.values[lastIdx];
    var labels = [];
    if (d.annotations) {
      d.annotations.forEach(function(ann) {
        labels.push({ dsi: 0, idx: ann.index, text: fmtM(ann.value), color: TEXT, yOff: -14 });
      });
    }
    var lastPointData = [];
    for (var i = 0; i < d.values.length; i++) {
      lastPointData.push(i === lastIdx ? lastVal : null);
    }
    var _c = new Chart(canvas, {
      type: "line",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          borderColor: PRIMARY,
          backgroundColor: "rgba(74,159,212,0.15)",
          fill: true,
          pointRadius: 0,
          borderWidth: 2,
          tension: 0.3
        }, {
          data: lastPointData,
          pointRadius: 6,
          pointBackgroundColor: ACCENT2,
          showLine: false,
          borderWidth: 0
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            beginAtZero: true
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 20 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  // 3. Films Watched CAGR
  renderers.films_watched_cagr = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : d.values.indexOf(Math.max.apply(null, d.values));
    var colors = d.values.map(function(_, i) {
      return i === peakIndex ? ACCENT2 : PRIMARY;
    });
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === 0 || i === d.values.length - 1) {
        labels.push({ dsi: 0, idx: i, text: fmtM(v), color: TEXT });
      }
    });
    var _c = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          backgroundColor: colors,
          barPercentage: 0.82,
          categoryPercentage: 0.82
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            beginAtZero: true,
            suggestedMax: withHeadroom(d.values, 0.15)
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin, cagrPlugin]
    });
    _c.config._labels = labels;
    _c.config._cagrData = { cagr: d.cagr, offset: 35 };
    _c.update();
  };

  // 4. YoY Films Watched
  renderers.yoy_films_watched = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : d.values.indexOf(Math.max.apply(null, d.values.map(Math.abs)));
    var negIndices = d.negativeIndices || [];
    var minIdx = d.values.indexOf(Math.min.apply(null, d.values));
    var colors = d.values.map(function(_, i) {
      if (i === peakIndex) return ACCENT2;
      if (i === minIdx) return ACCENT1;
      if (negIndices.indexOf(i) >= 0) return ACCENT1;
      return PRIMARY;
    });
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === peakIndex || i === minIdx || (negIndices.length > 0 && negIndices.indexOf(i) >= 0)) {
        var sign = v >= 0 ? "+" : "\u2212";
        var text = sign + Math.abs(v).toFixed(1) + "%";
        var yOff = v >= 0 ? -6 : 14;
        labels.push({ dsi: 0, idx: i, text: text, color: TEXT, yOff: yOff });
      }
    });
    var minVal = Math.min.apply(null, d.values);
    var maxVal = Math.max.apply(null, d.values);
    var _c = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          backgroundColor: colors,
          barPercentage: 0.82,
          categoryPercentage: 0.82
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            beginAtZero: true,
            suggestedMin: minVal < 0 ? minVal * 1.2 : 0,
            suggestedMax: withHeadroom(d.values, 0.1)
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin, zeroLinePlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  // 5. YoY All Metrics Grid
  renderers.yoy_all_metrics = function(canvas, d) {
    if (!d || !d.metrics) return;
    var container = document.createElement("div");
    container.className = "chart-yir-grid";
    canvas.parentNode.replaceChild(container, canvas);
    var globalMin = d.globalMin || -5;
    var globalMax = d.globalMax || 350;
    d.metrics.forEach(function(metric) {
      var cell = document.createElement("div");
      cell.className = "chart-yir-cell";
      var cellCanvas = document.createElement("canvas");
      cell.appendChild(cellCanvas);
      container.appendChild(cell);
      var peakIndex = metric.peakIndex !== undefined ? metric.peakIndex : metric.values.indexOf(Math.max.apply(null, metric.values.map(Math.abs)));
      var negIndices = metric.negativeIndices || [];
      var colors = metric.values.map(function(_, i) {
        if (i === peakIndex) return ACCENT2;
        if (negIndices.indexOf(i) >= 0) return ACCENT1;
        return PRIMARY;
      });
      var labels = [];
      labels.push({ dsi: 0, idx: peakIndex, text: (metric.values[peakIndex] >= 0 ? "+" : "\u2212") + Math.abs(metric.values[peakIndex]).toFixed(1) + "%", color: TEXT, yOff: metric.values[peakIndex] >= 0 ? -6 : 14 });
      var _c = new Chart(cellCanvas, {
        type: "bar",
        data: {
          labels: metric.years,
          datasets: [{
            data: metric.values,
            backgroundColor: colors,
            barPercentage: 0.82,
            categoryPercentage: 0.82
          }]
        },
        options: {
          scales: {
            x: {
              grid: { display: false },
              border: { color: TEXT, width: 1 },
              ticks: { color: TEXT, font: { size: 11 } }
            },
            y: {
              display: false,
              min: 0,
              suggestedMax: withHeadroom(metric.values, 0.1)
            }
          },
          layout: { padding: { left: 16, right: 16, bottom: 8 } },
          aspectRatio: 1.2,
          plugins: {
            title: {
              display: true,
              text: metric.name,
              color: TEXT,
              font: { size: 11 }
            }
          }
        },
        plugins: [labelPlugin]
      });
      _c.config._labels = labels;
      _c.update();
    });
  };

  // 6. Platform Metrics Growth
  renderers.platform_metrics_growth = function(canvas, d) {
    if (!d || !d.metrics) return;
    var container = document.createElement("div");
    container.className = "chart-yir-grid";
    canvas.parentNode.replaceChild(container, canvas);
    d.metrics.forEach(function(metric) {
      var cell = document.createElement("div");
      cell.className = "chart-yir-cell";
      var cellCanvas = document.createElement("canvas");
      cell.appendChild(cellCanvas);
      container.appendChild(cell);
      var peakIndex = metric.peakIndex !== undefined ? metric.peakIndex : metric.values.indexOf(Math.max.apply(null, metric.values));
      var colors = metric.values.map(function(_, i) {
        return i === peakIndex ? ACCENT2 : PRIMARY;
      });
      var labels = [{ dsi: 0, idx: peakIndex, text: fmtM(metric.values[peakIndex]), color: TEXT }];
      var _c = new Chart(cellCanvas, {
        type: "bar",
        data: {
          labels: metric.years,
          datasets: [{
            data: metric.values,
            backgroundColor: colors,
            barPercentage: 0.82,
            categoryPercentage: 0.82
          }]
        },
        options: {
          scales: {
            x: {
              grid: { display: false },
              border: { color: TEXT, width: 1 },
              ticks: { color: TEXT, font: { size: 11 } }
            },
            y: {
              display: false,
              beginAtZero: true,
              suggestedMax: withHeadroom(metric.values, 0.1)
            }
          },
          layout: { padding: { left: 16, right: 16, bottom: 8 } },
          aspectRatio: 1.2,
          plugins: {
            title: {
              display: true,
              text: metric.name,
              color: TEXT,
              font: { size: 11 }
            }
          }
        },
        plugins: [labelPlugin]
      });
      _c.config._labels = labels;
      _c.update();
    });
  };

  // 7. Platform Metrics CAGR
  renderers.platform_metrics_cagr = function(canvas, d) {
    if (!d || !d.metrics) return;
    var container = document.createElement("div");
    container.className = "chart-yir-grid";
    canvas.parentNode.replaceChild(container, canvas);
    d.metrics.forEach(function(metric) {
      var cell = document.createElement("div");
      cell.className = "chart-yir-cell";
      var cellCanvas = document.createElement("canvas");
      cell.appendChild(cellCanvas);
      container.appendChild(cell);
      var peakIndex = metric.peakIndex !== undefined ? metric.peakIndex : metric.values.indexOf(Math.max.apply(null, metric.values));
      var colors = metric.values.map(function(_, i) {
        return i === peakIndex ? ACCENT2 : PRIMARY;
      });
      var _c = new Chart(cellCanvas, {
        type: "bar",
        data: {
          labels: metric.years,
          datasets: [{
            data: metric.values,
            backgroundColor: colors,
            barPercentage: 0.82,
            categoryPercentage: 0.82
          }]
        },
        options: {
          scales: {
            x: {
              grid: { display: false },
              border: { color: TEXT, width: 1 },
              ticks: { color: TEXT, font: { size: 11 } }
            },
            y: {
              display: false,
              beginAtZero: true,
              suggestedMax: withHeadroom(metric.values, 0.15)
            }
          },
          layout: { padding: { left: 16, right: 16, bottom: 8 } },
          aspectRatio: 1.2,
          plugins: {
            title: {
              display: true,
              text: metric.name,
              color: TEXT,
              font: { size: 11 }
            }
          }
        },
        plugins: [cagrPlugin]
      });
      _c.config._cagrData = { cagr: metric.cagr, offset: 10 };
      _c.update();
    });
  };

  // 8. Indexed Growth
  renderers.indexed_growth = function(canvas, d) {
    if (!d || !d.lines) return;
    var datasets = d.lines.map(function(line) {
      return {
        label: line.name,
        data: line.values,
        borderColor: line.isBest ? ACCENT2 : MUTED,
        borderWidth: line.isBest ? 3 : 1.5,
        pointRadius: 0,
        fill: false,
        tension: 0.3
      };
    });
    var _c = new Chart(canvas, {
      type: "line",
      data: {
        labels: d.years,
        datasets: datasets
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            beginAtZero: true
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 30 } },
        aspectRatio: 2.2
      },
      plugins: [endLabelsPlugin]
    });
  };

  // 9. Share Released in Year
  renderers.share_released_in_year = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : 0;
    var minIndex = d.minIndex !== undefined ? d.minIndex : 0;
    var avgIndex = d.avgIndex !== undefined ? d.avgIndex : d.values.length - 1;
    var colors = d.values.map(function(_, i) {
      if (i === avgIndex) return MUTED;
      if (i === peakIndex) return ACCENT2;
      if (i === minIndex) return ACCENT1;
      return PRIMARY;
    });
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === peakIndex || i === minIndex || i === avgIndex) {
        labels.push({ dsi: 0, idx: i, text: v.toFixed(1) + "%", color: TEXT });
      }
    });
    var _c = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          backgroundColor: colors,
          barPercentage: 0.82,
          categoryPercentage: 0.82
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            min: 10,
            suggestedMax: withHeadroom(d.values, 0.08)
          }
        },
        layout: { padding: { left: 16, right: 16, bottom: 8, top: 18 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  // 10. Average Watch Time
  renderers.average_watch_time = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : d.values.indexOf(Math.max.apply(null, d.values));
    var minIndex = d.minIndex !== undefined ? d.minIndex : d.values.indexOf(Math.min.apply(null, d.values));
    var pointBgColor = d.values.map(function(_, i) {
      if (i === peakIndex) return ACCENT2;
      if (i === minIndex) return ACCENT1;
      return PRIMARY;
    });
    var pointRad = d.values.map(function(_, i) {
      if (i === peakIndex || i === minIndex) return 6;
      return 4;
    });
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === peakIndex || i === minIndex || i === 0 || i === d.values.length - 1) {
        labels.push({ dsi: 0, idx: i, text: v.toFixed(1) + " min", color: TEXT, yOff: -14 });
      }
    });
    var _c = new Chart(canvas, {
      type: "line",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          borderColor: PRIMARY,
          pointBackgroundColor: pointBgColor,
          pointRadius: pointRad,
          fill: false,
          tension: 0.3
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false
          }
        },
        layout: { padding: { left: 30, right: 40, bottom: 8, top: 20 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  // 11. Review Rate
  renderers.review_rate = function(canvas, d) {
    if (!d || !d.years || !d.values) return;
    var peakIndex = d.peakIndex !== undefined ? d.peakIndex : d.values.indexOf(Math.max.apply(null, d.values));
    var minIndex = d.minIndex !== undefined ? d.minIndex : d.values.indexOf(Math.min.apply(null, d.values));
    var pointBgColor = d.values.map(function(_, i) {
      if (i === peakIndex) return ACCENT2;
      if (i === minIndex) return ACCENT1;
      return PRIMARY;
    });
    var pointRad = d.values.map(function(_, i) {
      if (i === peakIndex || i === minIndex) return 6;
      return 4;
    });
    var labels = [];
    d.values.forEach(function(v, i) {
      if (i === peakIndex || i === minIndex || i === 0 || i === d.values.length - 1) {
        labels.push({ dsi: 0, idx: i, text: v.toFixed(1) + "%", color: TEXT, yOff: -14 });
      }
    });
    var _c = new Chart(canvas, {
      type: "line",
      data: {
        labels: d.years,
        datasets: [{
          data: d.values,
          borderColor: PRIMARY,
          pointBackgroundColor: pointBgColor,
          pointRadius: pointRad,
          fill: false,
          tension: 0.3
        }]
      },
      options: {
        scales: {
          x: {
            grid: { display: false },
            border: { color: TEXT, width: 1 },
            ticks: { color: TEXT, font: { size: 11 } }
          },
          y: {
            display: false,
            min: 15
          }
        },
        layout: { padding: { left: 30, right: 40, bottom: 8, top: 20 } },
        aspectRatio: 2.2
      },
      plugins: [labelPlugin]
    });
    _c.config._labels = labels;
    _c.update();
  };

  function init() {
    Chart.defaults.color = TEXT;
    Chart.defaults.font.family = "'Helvetica Neue', Arial, sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.plugins.legend.display = false;
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = true;

    document.querySelectorAll("canvas[data-chart]").forEach(function(canvas) {
      var key = canvas.getAttribute("data-chart");
      if (renderers[key] && D[key]) {
        renderers[key](canvas, D[key]);
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
