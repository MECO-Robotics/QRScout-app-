const columns = [
  "scout",
  "match",
  "team",
  "alliance",
  "station",
  "robotNotes",
  "autoFuelScored",
  "autoFuelMissed",
  "autoTowerLevel1",
  "teleopFuelScored",
  "teleopFuelMissed",
  "teleopFuelInactive",
  "fouls",
  "defenseRating",
  "towerLevel",
  "comments",
];

const form = document.querySelector("#scouting-form");
const payloadOutput = document.querySelector("#payload");
const qrContainer = document.querySelector("#qr-code");
const toast = document.querySelector("#toast");
const counterElements = [...document.querySelectorAll(".counter")];
let toastTimer;
let qrCode;

function sanitize(value) {
  return String(value ?? "")
    .replaceAll(",", " ")
    .replaceAll("\n", " ")
    .trim();
}

function selectedValue(name) {
  return form.elements[name].value;
}

function boundedCounterValue(counter) {
  const input = counter.querySelector("input");
  const maximum = Number(counter.dataset.max);
  const parsed = Number.parseInt(input.value, 10);
  const value = Number.isFinite(parsed) ? Math.max(0, Math.min(maximum, parsed)) : 0;
  input.value = String(value);
  return String(value);
}

function values() {
  const counters = Object.fromEntries(
    counterElements.map((counter) => [counter.dataset.counter, boundedCounterValue(counter)]),
  );

  return [
    sanitize(form.elements.scout.value),
    sanitize(form.elements.match.value),
    sanitize(form.elements.team.value),
    selectedValue("alliance"),
    selectedValue("station"),
    sanitize(form.elements.robotNotes.value),
    counters.autoFuelScored,
    counters.autoFuelMissed,
    counters.autoTowerLevel1,
    counters.teleopFuelScored,
    counters.teleopFuelMissed,
    counters.teleopFuelInactive,
    counters.fouls,
    counters.defenseRating,
    selectedValue("towerLevel"),
    sanitize(form.elements.comments.value),
  ];
}

function drawFallbackQR(text) {
  qrContainer.replaceChildren();
  const canvas = document.createElement("canvas");
  const size = 220;
  const cells = 29;
  const cell = size / cells;
  const context = canvas.getContext("2d");
  let state = [...text].reduce((hash, character) => ((hash * 31) + character.charCodeAt(0)) >>> 0, 2166136261);

  canvas.width = size;
  canvas.height = size;
  context.fillStyle = "#fff";
  context.fillRect(0, 0, size, size);
  context.fillStyle = "#000";

  const drawFinder = (startX, startY) => {
    context.fillRect(startX * cell, startY * cell, 7 * cell, 7 * cell);
    context.fillStyle = "#fff";
    context.fillRect((startX + 1) * cell, (startY + 1) * cell, 5 * cell, 5 * cell);
    context.fillStyle = "#000";
    context.fillRect((startX + 2) * cell, (startY + 2) * cell, 3 * cell, 3 * cell);
  };

  drawFinder(1, 1);
  drawFinder(cells - 8, 1);
  drawFinder(1, cells - 8);

  for (let row = 0; row < cells; row += 1) {
    for (let column = 0; column < cells; column += 1) {
      const inFinder =
        (row >= 1 && row <= 7 && column >= 1 && column <= 7)
        || (row >= 1 && row <= 7 && column >= cells - 8 && column <= cells - 2)
        || (row >= cells - 8 && row <= cells - 2 && column >= 1 && column <= 7);
      if (inFinder) continue;
      state ^= state << 13;
      state ^= state >>> 17;
      state ^= state << 5;
      if ((state >>> 0) % 2 === 0) {
        context.fillRect(column * cell, row * cell, Math.ceil(cell), Math.ceil(cell));
      }
    }
  }

  canvas.setAttribute("aria-hidden", "true");
  qrContainer.append(canvas);
}

function renderQR(payload) {
  if (typeof window.QRCode !== "function") {
    drawFallbackQR(payload);
    return;
  }

  if (!qrCode) {
    qrCode = new window.QRCode(qrContainer, {
      text: payload,
      width: 220,
      height: 220,
      colorDark: "#000000",
      colorLight: "#ffffff",
      correctLevel: window.QRCode.CorrectLevel.M,
    });
  } else {
    qrCode.clear();
    qrCode.makeCode(payload);
  }
}

function updateOutput() {
  const payload = values().join(",");
  payloadOutput.textContent = payload;
  renderQR(payload);
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add("visible");
  toastTimer = window.setTimeout(() => toast.classList.remove("visible"), 2300);
}

async function copyText(text, successMessage) {
  try {
    await navigator.clipboard.writeText(text);
    showToast(successMessage);
  } catch {
    const helper = document.createElement("textarea");
    helper.value = text;
    helper.style.position = "fixed";
    helper.style.opacity = "0";
    document.body.append(helper);
    helper.select();
    document.execCommand("copy");
    helper.remove();
    showToast(successMessage);
  }
}

counterElements.forEach((counter) => {
  const input = counter.querySelector("input");
  counter.querySelectorAll("button").forEach((button) => {
    button.addEventListener("click", () => {
      input.value = String(Number(boundedCounterValue(counter)) + Number(button.dataset.step));
      boundedCounterValue(counter);
      updateOutput();
    });
  });
  input.addEventListener("input", updateOutput);
  input.addEventListener("blur", updateOutput);
});

form.addEventListener("input", updateOutput);
form.addEventListener("change", updateOutput);
form.addEventListener("submit", (event) => event.preventDefault());

document.querySelector("#reset-button").addEventListener("click", () => {
  const currentMatch = form.elements.match.value.trim();
  const nextMatch = /^\d+$/.test(currentMatch) ? String(Number(currentMatch) + 1) : "";
  const currentScout = form.elements.scout.value;
  const currentAlliance = selectedValue("alliance");

  form.reset();
  form.elements.scout.value = currentScout;
  form.elements.match.value = nextMatch;
  form.elements.alliance.value = currentAlliance;
  counterElements.forEach((counter) => {
    counter.querySelector("input").value = "0";
  });
  updateOutput();
  showToast("Form reset for the next match.");
});

document.querySelector("#commit-button").addEventListener("click", () => {
  updateOutput();
  const dialog = document.querySelector("#commit-dialog");
  if (typeof dialog.showModal === "function") {
    dialog.showModal();
  } else {
    showToast("QR Code Ready — the scouting payload has been encoded.");
  }
});

document.querySelector("#copy-payload").addEventListener("click", () => {
  copyText(payloadOutput.textContent, "Payload copied to the clipboard.");
});

document.querySelector("#copy-columns").addEventListener("click", () => {
  copyText(columns.join(","), "Column names copied to the clipboard.");
});

updateOutput();
