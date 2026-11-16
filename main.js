const apiBaseUrl = "http://127.0.0.1:4000";

const money = (amount) =>
  new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    maximumFractionDigits: 0
  }).format(amount);

const state = {
  route: "customer",
  hotelCategory: "all",
  bookingFilter: "all",
  selectedThemeId: null,
  hotels: [
    {
      id: "hotel-joy-1",
      name: "Joy Boutique Quận 1",
      category: "near",
      type: "hourly",
      district: "Quận 1",
      rating: 4.8,
      price: 180000,
      image: "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1000&q=80",
      tags: ["Gần bạn", "Theo giờ", "VNPay"]
    },
    {
      id: "hotel-love-2",
      name: "Lumi Love Hotel",
      category: "love",
      type: "overnight",
      district: "Quận 3",
      rating: 4.6,
      price: 520000,
      image: "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1000&q=80",
      tags: ["Tình yêu", "Qua đêm", "Ưu đãi"]
    },
    {
      id: "hotel-top-3",
      name: "Aurora Signature Stay",
      category: "top",
      type: "daily",
      district: "Quận 7",
      rating: 4.9,
      price: 760000,
      image: "https://images.unsplash.com/photo-1564501049412-61c2a3083791?auto=format&fit=crop&w=1000&q=80",
      tags: ["Top 10", "Theo ngày", "Đánh giá tốt"]
    }
  ],
  locations: [],
  themes: [],
  sessions: [],
  promotions: [],
  bookings: []
};

function showToast(message) {
  const toast = document.querySelector("#toast");
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 2200);
}

async function fetchJson(path, options = {}) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    headers: {
      "content-type": "application/json; charset=utf-8"
    },
    ...options
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error ?? response.statusText ?? "Request failed");
  }

  return payload;
}

function getThemeSessions(themeId) {
  return state.sessions.filter((session) => session.themeId === themeId);
}

function formatSessionTime(session) {
  try {
    const start = new Date(session.startAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
    const end = new Date(session.endAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
    return `${start} - ${end}`;
  } catch {
    return session.time ?? "Không xác định";
  }
}

async function loadEscapeCatalog({ query = "", locationId = "" } = {}) {
  const params = new URLSearchParams();
  if (query) params.set("query", query);
  if (locationId) params.set("locationId", locationId);
  const path = `/api/escape/catalog?${params.toString()}`;
  const payload = await fetchJson(path);

  state.locations = payload.data.locations;
  state.themes = payload.data.themes;
  state.sessions = payload.data.sessions;
  state.promotions = payload.data.promotions;
  if (!state.selectedThemeId && state.themes.length) {
    state.selectedThemeId = state.themes[0].id;
  }
}

async function loadMerchantBookings(status = "") {
  let path = "/api/merchant/bookings";
  if (status && status !== "all") path += `?status=${encodeURIComponent(status)}`;
  const payload = await fetchJson(path);
  state.bookings = payload.data;
}

async function createBooking({ themeId, sessionId, players, coupon }) {
  const payload = {
    userId: "user-demo",
    sessionId,
    playerCount: players,
    promotionCode: coupon || undefined
  };

  const response = await fetchJson("/api/bookings/escape-room", {
    method: "POST",
    body: JSON.stringify(payload)
  });

  state.bookings.unshift(response.data);
  showToast(`Đã tạo ${response.data.code}`);
  await loadEscapeCatalog();
  await loadMerchantBookings(state.bookingFilter);
  routeTo("portal");
}

async function markBookingPaid(bookingId) {
  const response = await fetchJson(`/api/bookings/${bookingId}/mark-paid`, {
    method: "POST",
    body: JSON.stringify({})
  });

  const updatedBooking = response.data;
  const index = state.bookings.findIndex((booking) => booking.id === updatedBooking.id);
  if (index !== -1) {
    state.bookings[index] = updatedBooking;
  }

  showToast(`${updatedBooking.code} đã thanh toán`);
  await loadMerchantBookings(state.bookingFilter);
  render();
}

function getStatusClass(status) {
  if (status === "paid" || status === "waiting_checkin") return "green";
  if (status === "waiting_payment") return "red";
  return "amber";
}

function routeTo(route) {
  state.route = route;
  document.querySelectorAll(".view").forEach((view) => view.classList.toggle("active", view.dataset.view === route));
  document.querySelectorAll(".nav-button").forEach((button) => button.classList.toggle("active", button.dataset.route === route));
  render();
}

function renderHotels() {
  const query = document.querySelector("#hotelSearchInput")?.value?.toLowerCase() ?? "";
  const type = document.querySelector("#hotelTypeSelect")?.value ?? "all";
  const hotels = state.hotels.filter((hotel) => {
    const categoryMatch = state.hotelCategory === "all" || hotel.category === state.hotelCategory;
    const typeMatch = type === "all" || hotel.type === type;
    const queryMatch = !query || `${hotel.name} ${hotel.district} ${hotel.tags.join(" ")}`.toLowerCase().includes(query);
    return categoryMatch && typeMatch && queryMatch;
  });

  document.querySelector("#hotelGrid").innerHTML = hotels
    .map(
      (hotel) => `
        <article class="hotel-card">
          <img src="${hotel.image}" alt="${hotel.name}">
          <div class="card-body">
            <div class="meta-row">
              ${hotel.tags.map((tag) => `<span class="status-pill teal">${tag}</span>`).join("")}
            </div>
            <h3>${hotel.name}</h3>
            <p>${hotel.district} · ${hotel.rating} sao · từ <strong>${money(hotel.price)}</strong></p>
            <button class="primary-button" data-hotel-id="${hotel.id}">Xem phòng</button>
          </div>
        </article>
      `
    )
    .join("");
}

function renderEscapeList() {
  const query = document.querySelector("#escapeSearchInput")?.value?.toLowerCase() ?? "";
  const playerFilter = document.querySelector("#playerFilter")?.value ?? "all";

  const themes = state.themes
    .map((theme) => ({ ...theme, sessions: getThemeSessions(theme.id) }))
    .filter((theme) => {
      const textMatch = !query || `${theme.name} ${theme.category}`.toLowerCase().includes(query);
      const playerMatch = playerFilter === "all" || Number(playerFilter) >= theme.minPlayers;
      return textMatch && playerMatch;
    });

  document.querySelector("#escapeList").innerHTML =
    themes
      .map((theme) => {
        const location = state.locations.find((item) => item.id === theme.locationId) ?? { name: "Địa điểm không xác định" };
        const nextSession = theme.sessions[0];
        const sessionCount = theme.sessions.length;

        return `
        <article class="escape-card">
          <div class="escape-thumb"></div>
          <div>
            <div class="meta-row">
              <span class="status-pill violet">${theme.category}</span>
              <span class="status-pill">${theme.minPlayers}-${theme.maxPlayers} người</span>
            </div>
            <h3>${theme.name}</h3>
            <p>${location.name}</p>
            <p>${theme.description}</p>
            <p><strong>${money(theme.basePrice)}</strong> / người</p>
            <p>${sessionCount} suất chơi khả dụng</p>
            <p>Suất đầu tiên: ${nextSession ? formatSessionTime(nextSession) : "Không có suất"}</p>
          </div>
          <button class="table-action" data-theme-id="${theme.id}">Chọn</button>
        </article>
      `;
      })
      .join("");
}

function renderBookingPanel() {
  const theme = state.themes.find((item) => item.id === state.selectedThemeId);
  if (!theme) {
    document.querySelector("#bookingPanel").innerHTML = `
      <h2>Chọn chủ đề Escape Room</h2>
      <p>Vui lòng chọn một chủ đề bên trái để xem suất chơi và đặt phòng.</p>
    `;
    return;
  }

  const location = state.locations.find((item) => item.id === theme.locationId) ?? { name: "Địa điểm không xác định" };
  const sessions = getThemeSessions(theme.id);
  const playerOptions = Array.from({ length: theme.maxPlayers - theme.minPlayers + 1 }, (_, index) => theme.minPlayers + index);

  document.querySelector("#bookingPanel").innerHTML = `
    <h2>${theme.name}</h2>
    <p>${location.name}</p>
    <div class="session-list">
      ${sessions
        .map(
          (session, index) => `
            <label class="session-row">
              <span>
                <strong>${formatSessionTime(session)}</strong><br>
                <small>${session.bookedCount}/${session.capacityMax} người · ${session.status}</small>
              </span>
              <input name="session" type="radio" value="${session.id}" ${index === 0 ? "checked" : ""}>
            </label>
          `
        )
        .join("")}
    </div>
    <form id="bookingForm">
      <label>
        Số người chơi
        <select name="players">
          ${playerOptions.map((count) => `<option value="${count}">${count} người</option>`).join("")}
        </select>
      </label>
      <label>
        Coupon
        <input name="coupon" value="EMES15">
      </label>
      <div class="price-line total">
        <span>Tạm tính</span>
        <strong>${money(theme.basePrice * theme.minPlayers)}</strong>
      </div>
      <button type="submit">Đặt phòng chơi qua VNPay</button>
    </form>
  `;
}

function renderStats() {
  const debt = state.bookings.reduce((sum, booking) => sum + (booking.finalAmount ?? 0), 0);
  const paid = state.bookings.filter((booking) => booking.paymentStatus === "paid").length;
  const statItems = [
    ["Địa điểm", state.locations.length],
    ["Chủ đề", state.themes.length],
    ["Booking", state.bookings.length],
    ["Đã thanh toán", paid]
  ];
  const html = statItems.map(([label, value]) => `<article class="stat"><span>${label}</span><strong>${value}</strong></article>`).join("");
  document.querySelector("#portalStats").innerHTML = html;
  document.querySelector("#adminStats").innerHTML = html;
  document.querySelector("#settlementDebt").textContent = money(debt);
}

function renderBookings() {
  const bookings = state.bookings.filter((booking) => state.bookingFilter === "all" || booking.status === state.bookingFilter);
  document.querySelector("#bookingRows").innerHTML =
    bookings
      .map(
        (booking) => `
          <tr>
            <td><strong>${booking.code}</strong></td>
            <td>${booking.serviceType === "escape_room" ? "Escape Room" : booking.service || "N/A"}</td>
            <td>${booking.customer ?? booking.userId}</td>
            <td>${booking.playerCount}</td>
            <td><span class="status-pill amber">${booking.status}</span></td>
            <td><span class="status-pill ${getStatusClass(booking.paymentStatus)}">${booking.paymentStatus}</span></td>
            <td>${money(booking.finalAmount)}</td>
            <td><button class="table-action" data-pay-booking="${booking.id}">Mark paid</button></td>
          </tr>
        `
      )
      .join("") || `<tr><td colspan="8">Chưa có booking. Chọn Escape Booking hoặc bấm tạo booking demo.</td></tr>`;
}

function render() {
  renderHotels();
  renderEscapeList();
  renderBookingPanel();
  renderStats();
  renderBookings();
}

async function initializeApp() {
  try {
    await loadEscapeCatalog();
    await loadMerchantBookings();
    render();
  } catch (error) {
    showToast(error.message);
  }
}

document.querySelectorAll("[data-route]").forEach((item) => {
  item.addEventListener("click", (event) => {
    event.preventDefault();
    routeTo(item.dataset.route);
  });
});

document.querySelector("#seedBookingButton").addEventListener("click", async () => {
  const theme = state.themes.find((item) => item.id === "theme-haunted-house");
  if (!theme) {
    showToast("Không tìm thấy chủ đề để tạo booking demo.");
    return;
  }
  const session = getThemeSessions(theme.id)[0];
  if (!session) {
    showToast("Không có suất chơi demo.");
    return;
  }

  await createBooking({ themeId: theme.id, sessionId: session.id, players: 3, coupon: "EMES15" });
});

document.querySelector("#hotelSearchButton").addEventListener("click", renderHotels);
document.querySelector("#escapeSearchButton").addEventListener("click", renderEscapeList);
document.querySelector("#hotelTypeSelect").addEventListener("change", renderHotels);
document.querySelector("#hotelSearchInput").addEventListener("input", renderHotels);

document.querySelectorAll("[data-hotel-category]").forEach((button) => {
  button.addEventListener("click", () => {
    state.hotelCategory = button.dataset.hotelCategory;
    document.querySelectorAll("[data-hotel-category]").forEach((item) => item.classList.toggle("active", item === button));
    renderHotels();
  });
});

document.querySelectorAll("[data-booking-filter]").forEach((button) => {
  button.addEventListener("click", async () => {
    state.bookingFilter = button.dataset.bookingFilter;
    document.querySelectorAll("[data-booking-filter]").forEach((item) => item.classList.toggle("active", item === button));
    await loadMerchantBookings(state.bookingFilter);
    renderBookings();
  });
});

document.querySelector("#escapeList").addEventListener("click", (event) => {
  const themeId = event.target.dataset.themeId;
  if (!themeId) return;
  state.selectedThemeId = themeId;
  renderBookingPanel();
});

document.querySelector("#bookingPanel").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = new FormData(event.target);
  await createBooking({
    themeId: state.selectedThemeId,
    sessionId: form.get("session"),
    players: Number(form.get("players")),
    coupon: String(form.get("coupon") || "")
  });
});

document.querySelector("#bookingRows").addEventListener("click", async (event) => {
  const bookingId = event.target.dataset.payBooking;
  if (!bookingId) return;
  await markBookingPaid(bookingId);
});

initializeApp();
