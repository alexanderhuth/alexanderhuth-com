(function () {
    var root = document.querySelector(".meet");
    if (!root) {
      return;
    }

    var configEl = root.querySelector("#meet-config");
    var overrideEl = root.querySelector("#meet-config-override");
    var durationEl = root.querySelector("#meet-duration");
    var meetConfig = null;

    var baseConfig = null;
    var overrideConfig = null;
    var overrideDuration = null;

    if (configEl) {
      try {
        baseConfig = JSON.parse(configEl.textContent);
      } catch (error) {
        baseConfig = null;
      }
    }

    if (overrideEl) {
      try {
        overrideConfig = JSON.parse(overrideEl.textContent);
      } catch (error) {
        overrideConfig = null;
      }
    }

    if (durationEl) {
      try {
        overrideDuration = JSON.parse(durationEl.textContent);
      } catch (error) {
        overrideDuration = null;
      }
    }

    if (baseConfig || overrideConfig) {
      meetConfig = Object.assign({}, baseConfig || {});
      if (overrideConfig) {
        if (overrideConfig.working_hours) {
          meetConfig.working_hours = Object.assign({}, meetConfig.working_hours || {}, overrideConfig.working_hours);
        }
        if (overrideConfig.durations) {
          meetConfig.durations = overrideConfig.durations;
        }
        if (overrideConfig.blocks) {
          meetConfig.blocks = overrideConfig.blocks;
        }
        Object.keys(overrideConfig).forEach(function (key) {
          if (key !== "working_hours" && key !== "durations" && key !== "blocks") {
            meetConfig[key] = overrideConfig[key];
          }
        });
      }

      if ((overrideConfig && overrideConfig.meet_duration) || overrideDuration) {
        var displayValue = Number((overrideConfig && overrideConfig.meet_duration) || overrideDuration);
        var bufferValue = (meetConfig && typeof meetConfig.meet_buffer_minutes === "number") ? meetConfig.meet_buffer_minutes : 5;
        meetConfig.durations = [
          {
            actual: Math.max(displayValue - bufferValue, 5),
            display: displayValue
          }
        ];
      }
    }

    var summary = root.querySelector("[data-summary]");
    var statusEl = root.querySelector("[data-status]");
    var daysContainer = root.querySelector("#slot-days");
    var durationRadios = root.querySelectorAll("input[name=\"duration-choice\"]");
    var durationInput = root.querySelector("#selected-duration");
    var slotInput = root.querySelector("#selected-slot");
    var form = root.querySelector(".meet-form");
    var slotTokenInput = root.querySelector("#slot-token");
    var turnstileInput = root.querySelector("#turnstile-token");
    var turnstileRequired = !!turnstileInput;

    var AVAILABILITY_ENDPOINT = "https://n8n.alexanderhuth.com/webhook/meet-availability";
    var BOOK_ENDPOINT = "https://n8n.alexanderhuth.com/webhook/meet-book";

    var availabilityData = null;

    if (!summary || !daysContainer) {
      return;
    }

    function setStatus(message) {
      if (!statusEl) {
        return;
      }
      statusEl.textContent = message || "";
    }

    function getActiveDuration() {
      var active = root.querySelector("input[name=\"duration-choice\"]:checked");
      if (!active) {
        if (meetConfig && Array.isArray(meetConfig.durations) && meetConfig.durations.length) {
          return Number(meetConfig.durations[0].actual) || 10;
        }
        return 10;
      }
      return parseInt(active.value, 10);
    }


    function getDisplayDuration() {
      var active = root.querySelector("input[name=\"duration-choice\"]:checked");
      if (!active) {
        if (meetConfig && Array.isArray(meetConfig.durations) && meetConfig.durations.length) {
          return Number(meetConfig.durations[0].display) || 15;
        }
        return 15;
      }
      return parseInt(active.getAttribute("data-display"), 10);
    }

    function formatDate(date) {
      return date.toLocaleDateString("en-GB", {
        weekday: "long",
        day: "2-digit",
        month: "long",
        year: "numeric"
      });
    }

    function getTimeZone() {
      var resolved = Intl.DateTimeFormat().resolvedOptions();
      return resolved && resolved.timeZone ? resolved.timeZone : "Local time";
    }

    function getTimeZoneShort() {
      var date = new Date();
      var parts = new Intl.DateTimeFormat(undefined, { timeZoneName: "short" }).formatToParts(date);
      var tzPart = parts.find(function (part) {
        return part.type === "timeZoneName";
      });
      return tzPart && tzPart.value ? tzPart.value : getTimeZone();
    }

    function toMinutes(timeText) {
      var parts = timeText.split(":");
      return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
    }

    function formatMinutes(total) {
      var hours = Math.floor(total / 60) % 24;
      var minutes = total % 60;
      var hh = String(hours);
      var mm = String(minutes).padStart(2, "0");
      return hh + ":" + mm;
    }

    function formatUserTime(date) {
      return new Intl.DateTimeFormat(undefined, {
        hour: "numeric",
        minute: "2-digit",
        hour12: false
      }).format(date);
    }

    function pad(value) {
      return String(value).padStart(2, "0");
    }

    function formatDateTimeWithOffset(date) {
      var year = date.getFullYear();
      var month = pad(date.getMonth() + 1);
      var day = pad(date.getDate());
      var hours = pad(date.getHours());
      var minutes = pad(date.getMinutes());
      var seconds = pad(date.getSeconds());
      var offsetMinutes = -date.getTimezoneOffset();
      var sign = offsetMinutes >= 0 ? "+" : "-";
      var abs = Math.abs(offsetMinutes);
      var offHours = pad(Math.floor(abs / 60));
      var offMinutes = pad(abs % 60);
      return year + "-" + month + "-" + day + "T" + hours + ":" + minutes + ":" + seconds + sign + offHours + ":" + offMinutes;
    }


    function getSlotInterval() {
      return (meetConfig && meetConfig.slot_interval_minutes) ? meetConfig.slot_interval_minutes : 30;
    }

    function getWorkingHours() {
      return (meetConfig && meetConfig.working_hours) ? meetConfig.working_hours : null;
    }

    function getBlocks() {
      return (meetConfig && Array.isArray(meetConfig.blocks)) ? meetConfig.blocks : [];
    }

    function isAllowedDay(day) {
      var working = getWorkingHours();
      if (!working || !Array.isArray(working.days)) {
        return true;
      }
      var dayDate = new Date(day.date + "T00:00:00");
      return working.days.indexOf(dayDate.getDay()) !== -1;
    }


    function renderAvailability(data, duration) {
      if (!data) {
        daysContainer.innerHTML = "Couldn't find any free slots. Shoot me an <a href=\"mailto:alexander.huth@gmail.com\">email</a>.";
        return;
      }

      if (data.days && data.days.length > 0 && data.days[0].slots) {
        var timeZone = getTimeZoneShort();
        var totalSlots = 0;
        var renderedDays = 0;
        daysContainer.innerHTML = "";

        data.days.forEach(function (day) {
          if (!isAllowedDay(day)) {
            return;
          }
          var slots = day.slots || [];
          if (slots.length === 0) {
            return;
          }

          var dayDetails = document.createElement("details");
          dayDetails.className = "meet-day";
          dayDetails.open = renderedDays === 0;

          var daySummary = document.createElement("summary");
          daySummary.textContent = day.label || day.date;
          dayDetails.appendChild(daySummary);

          var list = document.createElement("div");
          var slotCount = 0;

          slots.forEach(function (slot, index) {
            var slotStartMin = toMinutes(slot.start);
            var slotEndMin = toMinutes(slot.end);
            var working = getWorkingHours();
            var workStart = working && working.start ? toMinutes(working.start) : 0;
            var workEnd = working && working.end ? toMinutes(working.end) : 24 * 60 - 1;
            if (slotEndMin <= workStart || slotStartMin >= workEnd) {
              return;
            }

            var blocks = getBlocks();
            if (blocks.length) {
              var dayDate = new Date(day.date + "T00:00:00");
              var dow = dayDate.getDay();
              var blocked = blocks.some(function (block) {
                if (!block || !Array.isArray(block.days) || block.days.indexOf(dow) === -1) return false;
                var bStart = toMinutes(block.start);
                var bEnd = toMinutes(block.end);
                return slotStartMin < bEnd && slotEndMin > bStart;
              });
              if (blocked) {
                return;
              }
            }
            var labelText = slot.label || (slot.start + " to " + slot.end);
            if (index === 0 && labelText.indexOf("(") === -1) {
              labelText += " (" + timeZone + ")";
            }

            var id = "slot-" + day.date + "-" + slot.start.replace(":", "");

            var row = document.createElement("div");
            row.className = "meet-slot-row";

            var input = document.createElement("input");
            input.className = "meet-slot";
            input.type = "radio";
            input.name = "slot";
            input.id = id;
            if (slot.start_iso && slot.end_iso) {
              input.value = slot.start_iso;
              input.dataset.end = slot.end_iso;
            } else {
              input.value = day.date + "T" + slot.start;
              input.dataset.end = slot.end;
            }
            if (slot.token || slot.slot_token) {
              input.dataset.token = slot.token || slot.slot_token;
            }
            if (renderedDays === 0 && slotCount === 0) {
              input.checked = true;
            }

            var label = document.createElement("label");
            label.setAttribute("for", id);
            label.textContent = labelText;

            row.appendChild(input);
            row.appendChild(label);
            list.appendChild(row);
            slotCount += 1;
          });

          if (slotCount > 0) {
            dayDetails.appendChild(list);
            daysContainer.appendChild(dayDetails);
            renderedDays += 1;
            totalSlots += slotCount;
          }
        });

        if (totalSlots === 0) {
          daysContainer.innerHTML = "Couldn't find any free slots. Shoot me an <a href=\"mailto:alexander.huth@gmail.com\">email</a>.";
        }
        return;
      }

      daysContainer.innerHTML = "Couldn't find any free slots. Shoot me an <a href=\"mailto:alexander.huth@gmail.com\">email</a>.";
    }

    function fetchAvailability() {
      var payload = {
        duration_minutes: getActiveDuration(),
        timezone: (meetConfig && meetConfig.timezone) ? meetConfig.timezone : getTimeZone(),
        viewer_timezone: getTimeZone(),
        min_notice_hours: (meetConfig && meetConfig.min_notice_hours) ? meetConfig.min_notice_hours : 12
      };

      setStatus("Loading availability...");

      return fetch(AVAILABILITY_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      }).then(function (response) {
        if (!response.ok) {
          throw new Error("Availability error");
        }
        return response.json();
      });
    }

    function refreshFromCache() {
      var duration = getActiveDuration();
      if (availabilityData) {
        renderAvailability(availabilityData, duration);
        updateSummary();
      } else {
        renderAvailability({ days: [] }, duration);
        updateSummary();
      }
    }

    function loadAvailability() {
      fetchAvailability()
        .then(function (data) {
          availabilityData = data;
          setStatus("Availability loaded.");
          refreshFromCache();
        })
        .catch(function () {
          setStatus("Could not load availability.");
          availabilityData = null;
          renderAvailability({ days: [] }, getActiveDuration());
          updateSummary();
        });
    }

    function updateSummary() {
      var checked = root.querySelector("input[name=\"slot\"]:checked");
      var displayDuration = getDisplayDuration();
      var tz = getTimeZoneShort();

      if (!checked) {
        summary.textContent = "Select a time above";
        if (slotInput) {
          slotInput.value = "";
        }
        if (slotTokenInput) {
          slotTokenInput.value = "";
        }
        return;
      }

      var day = checked.closest(".meet-day");
      var dayLabel = day ? day.querySelector("summary") : null;
      var timeLabel = day ? day.querySelector("label[for=\"" + checked.id + "\"]") : null;
      var dayText = dayLabel ? dayLabel.textContent : "";
      var timeText = timeLabel ? timeLabel.textContent : "";

      if (dayText && timeText) {
        var prefix = displayDuration + " min on Google Meet · " + dayText + ", " + timeText;
        if (timeText.indexOf("(") === -1) {
          summary.textContent = prefix + " (" + tz + ")";
        } else {
          summary.textContent = prefix;
        }
      }

      if (durationInput) {
        durationInput.value = String(getActiveDuration());
      }

      if (slotInput) {
        slotInput.value = checked.value;
      }

      if (slotTokenInput) {
        slotTokenInput.value = checked.dataset.token || "";
      }
    }

    function bookMeeting(payload) {
      return fetch(BOOK_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      }).then(function (response) {
        return response.json().then(function (data) {
          return { ok: response.ok, data: data };
        });
      });
    }

    function validateForm() {
      var nameInput = root.querySelector("#name");
      var emailInput = root.querySelector("#email");
      var name = nameInput ? nameInput.value.trim() : "";
      var email = emailInput ? emailInput.value.trim() : "";

      if (!name) {
        setStatus("Please enter your name.");
        return false;
      }

      if (!email) {
        setStatus("Please enter your email.");
        return false;
      }

      var emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
      if (!emailOk) {
        setStatus("Please enter a valid email.");
        return false;
      }

      if (turnstileRequired && (!turnstileInput || !turnstileInput.value)) {
        setStatus("Please complete the verification.");
        return false;
      }

      return true;
    }

    function updateSubmitState() {
      var nameInput = root.querySelector("#name");
      var emailInput = root.querySelector("#email");
      var button = root.querySelector(".cta-button");
      if (!button) {
        return;
      }
      var name = nameInput ? nameInput.value.trim() : "";
      var email = emailInput ? emailInput.value.trim() : "";
      var emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
      var turnstileOk = !turnstileRequired || (turnstileInput && turnstileInput.value);
      button.disabled = !(name && email && emailOk && turnstileOk);
    }

    function attachListeners() {
      root.addEventListener("change", function (event) {
        if (event.target && event.target.name === "slot") {
          updateSummary();
        }
        if (event.target && event.target.name === "duration-choice") {
          loadAvailability();
        }
      });

      if (form) {
                form.addEventListener("input", function (event) {
          if (event.target && (event.target.id === "name" || event.target.id === "email")) {
            updateSubmitState();
          }
        });

        updateSubmitState();
        form.addEventListener("submit", function (event) {
          event.preventDefault();
          var checked = root.querySelector("input[name=\"slot\"]:checked");
          if (!checked) {
            setStatus("Please pick a time slot first.");
            return;
          }

          if (!validateForm()) {
            return;
          }

          var payload = {
            duration_minutes: getActiveDuration(),
            display_duration_minutes: getDisplayDuration(),
            slot_start: checked.value,
            slot_end: checked.dataset.end || "",
            slot_token: slotTokenInput ? slotTokenInput.value : "",
            timezone: getTimeZone(),
            timezone_short: getTimeZoneShort(),
            name: root.querySelector("#name").value,
            email: root.querySelector("#email").value,
            notes: root.querySelector("#notes").value,
            turnstile_token: turnstileInput ? turnstileInput.value : ""
          };

          setStatus("Booking...");

          bookMeeting(payload)
            .then(function (result) {
              if (result && result.ok) {
                setStatus(result.data && result.data.message ? result.data.message : "Booked. See you then!");
              } else {
                setStatus(result && result.data && result.data.message ? result.data.message : "Booking failed. Please try another slot.");
              }
            })
            .catch(function () {
              setStatus("Booking failed. Please try another slot.");
            });
        });
      }
    }

    loadAvailability();
    attachListeners();
    if (turnstileInput) {
      window.onTurnstile = function (token) {
        turnstileInput.value = token || "";
        updateSubmitState();
      };
    }
  })();
