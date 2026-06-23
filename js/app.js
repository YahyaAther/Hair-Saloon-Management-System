// API Configuration
const API_BASE_URL = 'http://localhost:8000/api/index.php?action=';

// Session State
let currentUser = null;
let currentPage = 'dashboard';
let activeAptFilter = 'all';

// Global POS Cart State
let posCart = [];

// DOM Elements
const appLayout = document.getElementById('app');
const loginScreen = document.getElementById('login-screen');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const pageContainer = document.getElementById('page-container');
const pageTitle = document.getElementById('page-title');
const navItems = document.querySelectorAll('.nav-item');
const themeToggle = document.getElementById('theme-toggle');
const btnLogout = document.getElementById('btn-logout');

// Helper: Format Time (ex: 10:00:00 -> 10:00 AM)
function formatTime(timeStr) {
    if (!timeStr) return '';
    const [h, m] = timeStr.split(':');
    let hours = parseInt(h);
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12;
    return `${hours}:${m} ${ampm}`;
}

// Fetch helper with JWT header
async function fetchData(action, method = 'GET', body = null) {
    const headers = { 'Content-Type': 'application/json' };
    const token = localStorage.getItem('token');
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    
    const options = { method, headers };
    if (body) {
        options.body = JSON.stringify(body);
    }
    
    try {
        const res = await fetch(`${API_BASE_URL}${action}`, options);
        if (res.status === 401) {
            logout();
            return null;
        }
        const data = await res.json();
        if (!res.ok) {
            throw new Error(data.error || 'Server Error');
        }
        return data;
    } catch (e) {
        console.error(e);
        alert(e.message);
        return null;
    }
}

// Auth operations
function checkSession() {
    const token = localStorage.getItem('token');
    const userStr = localStorage.getItem('user');
    
    if (token && userStr) {
        currentUser = JSON.parse(userStr);
        showApp();
    } else {
        showLogin();
    }
}

function showLogin() {
    loginScreen.style.display = 'flex';
    appLayout.style.display = 'none';
}

function showApp() {
    loginScreen.style.display = 'none';
    appLayout.style.display = 'flex';
    
    // Update User Display in sidebar
    document.getElementById('user-display-name').textContent = currentUser.name;
    document.getElementById('user-display-role').textContent = currentUser.role.toUpperCase();
    document.getElementById('user-avatar').src = `https://ui-avatars.com/api/?name=${encodeURIComponent(currentUser.name)}&background=1c1c1c&color=e5a55d`;
    
    // Role-based navigation filtering
    const navStaff = document.getElementById('nav-staff');
    if (currentUser.role === 'receptionist') {
        if (navStaff) navStaff.style.display = 'none'; // Hide Staff management for receptionists
    } else {
        if (navStaff) navStaff.style.display = 'flex';
    }
    
    switchPage(currentPage);
}

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    currentUser = null;
    showLogin();
}

// Login form submit handler
if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        loginError.style.display = 'none';
        
        const usernameInput = document.getElementById('login-username');
        const passwordInput = document.getElementById('login-password');
        
        const payload = {
            username: usernameInput.value,
            password: passwordInput.value
        };
        
        const res = await fetchData('login', 'POST', payload);
        if (res && res.success) {
            localStorage.setItem('token', res.token);
            localStorage.setItem('user', JSON.stringify(res.user));
            currentUser = res.user;
            usernameInput.value = '';
            passwordInput.value = '';
            showApp();
        } else {
            loginError.textContent = 'Invalid username or password';
            loginError.style.display = 'block';
        }
    });
}

if (btnLogout) {
    btnLogout.addEventListener('click', (e) => {
        e.preventDefault();
        logout();
    });
}

// Screen Rendering Functions
async function renderDashboard() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading...</div>';

    const data = await fetchData('dashboard');
    if (!data) return;

    let commissionHtml = '';
    if (currentUser.role === 'admin') {
        const commissionReport = await fetchData('commission_report');
        if (commissionReport && commissionReport.length > 0) {
            commissionHtml = `
            <div style="background: var(--bg-card); border: 1px solid var(--border-light); padding: 24px; border-radius: var(--radius-lg); margin-top:24px;">
                <h4 style="margin-bottom: 20px;">Stylist Payout Leaderboard</h4>
                <div style="display:flex; flex-direction:column; gap:12px;">
                    ${commissionReport.map(item => `
                        <div style="display:flex; justify-content:space-between; align-items:center; padding:12px; background:var(--bg-glass); border-radius:var(--radius-md);">
                            <div style="display:flex; align-items:center; gap:12px;">
                                <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(item.stylist_name)}&background=random" style="width:32px; height:32px; border-radius:50%;">
                                <div>
                                    <div style="font-weight:500;">${item.stylist_name}</div>
                                    <div style="font-size:12px; color:var(--text-muted);">${item.role}</div>
                                </div>
                            </div>
                            <div style="font-weight:600; color:var(--accent-gold);">$${parseFloat(item.total_commission_earned).toFixed(2)}</div>
                        </div>
                    `).join('')}
                </div>
            </div>`;
        }
    }

    let appointmentsHtml = '';
    if (data.todayAppointmentsList && data.todayAppointmentsList.length > 0) {
        data.todayAppointmentsList.forEach(apt => {
            const statusClass = apt.status === 'active' ? 'status-active' : (apt.status === 'completed' ? 'status-completed' : (apt.status === 'cancelled' ? 'status-cancelled' : 'status-upcoming'));
            const statusLabel = apt.status;
            
            let actionButtons = '';
            if (apt.status === 'upcoming') {
                actionButtons = `<button class="btn btn-primary" onclick="updateAptStatus(${apt.id}, 'active')" style="padding: 6px 12px; font-size:12px;"><i class="ph ph-play"></i> Start</button>`;
            } else if (apt.status === 'active') {
                actionButtons = `<button class="btn" onclick="updateAptStatus(${apt.id}, 'completed')" style="padding: 6px 12px; font-size:12px; background:var(--success); color:#000;"><i class="ph ph-check"></i> Complete</button>`;
            }

            appointmentsHtml += `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 16px; background: var(--bg-glass); border-radius: var(--radius-md); border: 1px solid var(--border-light);">
                <div style="display: flex; align-items: center; gap: 16px;">
                    <div style="font-weight: 600; min-width: 70px;">${formatTime(apt.start_time)}</div>
                    <div style="width: 3px; height: 32px; background: ${apt.status === 'active' ? 'var(--success)' : 'var(--accent-gold)'}; border-radius: 4px;"></div>
                    <div>
                        <div style="font-weight: 500;">${apt.client_name} <span style="font-size:11px; font-weight:600; text-transform:uppercase; background:var(--border-color); padding:2px 6px; border-radius:4px; margin-left:6px;">${apt.client_type}</span></div>
                        <div style="font-size: 13px; color: var(--text-secondary);">${apt.service_name} • ${apt.duration_mins}m</div>
                    </div>
                </div>
                <div style="display: flex; align-items: center; gap: 16px;">
                    <div style="display: flex; align-items: center; gap: 6px; font-size: 13px;">
                        <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(apt.staff_name)}&background=random" style="width:24px; height:24px; border-radius:50%;">
                        <span style="color: var(--text-secondary);">${apt.staff_name.split(' ')[0]}</span>
                    </div>
                    <span style="text-transform:capitalize; font-size:12px; font-weight:500; display:flex; align-items:center; gap:6px;">
                        <span class="status-dot ${statusClass}"></span> ${statusLabel}
                    </span>
                    <div style="display:flex; gap:6px;">
                        ${actionButtons}
                        ${apt.status !== 'completed' && apt.status !== 'cancelled' ? `<button class="btn" onclick="updateAptStatus(${apt.id}, 'cancelled')" style="padding: 6px 12px; font-size:12px; background:rgba(248,113,113,0.1); color:var(--danger); border:1px solid rgba(248,113,113,0.2);"><i class="ph ph-x"></i> Cancel</button>` : ''}
                    </div>
                </div>
            </div>`;
        });
    } else {
        appointmentsHtml = '<div style="color:var(--text-muted); font-size: 14px; padding: 20px 0;">No appointments booked for today.</div>';
    }

    pageContainer.innerHTML = `
        <div class="fade-in">
            <h3 style="margin-bottom: 24px;">Welcome back, ${currentUser.name}</h3>
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-bottom: 32px;">
                <div class="stat-card" style="background: var(--bg-card); padding: 24px; border-radius: var(--radius-lg); border: 1px solid var(--border-light); backdrop-filter: var(--blur-xl);">
                    <div style="color: var(--text-secondary); font-size: 14px; margin-bottom: 8px;">Total Revenue Today</div>
                    <div style="font-size: 32px; font-weight: 600; font-family: var(--font-heading); color:var(--accent-gold);">$${parseFloat(data.totalRevenue).toFixed(2)}</div>
                </div>
                <div class="stat-card" style="background: var(--bg-card); padding: 24px; border-radius: var(--radius-lg); border: 1px solid var(--border-light); backdrop-filter: var(--blur-xl);">
                    <div style="color: var(--text-secondary); font-size: 14px; margin-bottom: 8px;">Appointments Today</div>
                    <div style="font-size: 32px; font-weight: 600; font-family: var(--font-heading);">${data.appointmentsToday}</div>
                </div>
                <div class="stat-card" style="background: var(--bg-card); padding: 24px; border-radius: var(--radius-lg); border: 1px solid var(--border-light); backdrop-filter: var(--blur-xl);">
                    <div style="color: var(--text-secondary); font-size: 14px; margin-bottom: 8px;">Total Clients</div>
                    <div style="font-size: 32px; font-weight: 600; font-family: var(--font-heading);">${data.totalClients}</div>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 24px; align-items: start;">
                <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); padding: 24px;">
                    <h4 style="margin-bottom: 20px;">Today's Appointments Queue</h4>
                    <div style="display: flex; flex-direction: column; gap: 16px;">
                        ${appointmentsHtml}
                    </div>
                </div>
                <div>
                    ${commissionHtml}
                </div>
            </div>
        </div>
    `;
}

async function updateAptStatus(id, status) {
    const res = await fetchData('appointments_update', 'POST', { id, status });
    if (res && res.success) {
        renderDashboard();
    }
}

async function renderAppointments() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading...</div>';
    const data = await fetchData('appointments');
    if (!data) return;

    // Filter appointments
    const filteredData = activeAptFilter === 'all' 
        ? data 
        : data.filter(apt => apt.status.toLowerCase() === activeAptFilter);

    let gridHtml = '';
    filteredData.forEach(apt => {
        const statusColor = apt.status === 'completed' ? 'var(--text-muted)' : (apt.status === 'cancelled' ? 'var(--danger)' : (apt.status === 'active' ? 'var(--success)' : 'var(--info)'));
        const statusBg = apt.status === 'completed' ? 'rgba(255, 255, 255, 0.05)' : (apt.status === 'cancelled' ? 'rgba(248, 113, 113, 0.1)' : (apt.status === 'active' ? 'rgba(52, 211, 153, 0.1)' : 'rgba(96, 165, 250, 0.1)'));

        gridHtml += `
        <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); padding: 20px;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px;">
                <div>
                    <span style="font-size: 12px; font-weight: 600; color: ${statusColor}; background: ${statusBg}; padding: 4px 10px; border-radius: 20px; text-transform:uppercase;">
                        ${apt.status}
                    </span>
                    <div style="font-size: 13px; font-weight:500; color: var(--text-primary); margin-top: 8px;">${apt.appointment_date} @ ${formatTime(apt.start_time)}</div>
                </div>
            </div>
            <div style="display: flex; flex-direction: column; gap: 4px; margin-bottom: 20px;">
                <div style="font-size: 18px; font-weight: 600; color: var(--text-primary);">${apt.client_name} <span style="font-size:11px; font-weight:600; text-transform:uppercase; background:var(--border-color); padding:2px 6px; border-radius:4px;">${apt.client_type}</span></div>
                <div style="font-size: 14px; color: var(--text-secondary); display: flex; align-items: center; gap: 6px;"><i class="ph ph-phone"></i> ${apt.client_phone || 'N/A'}</div>
            </div>
            <div style="padding-top: 16px; border-top: 1px solid var(--border-light); display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <div style="font-size: 12px; color: var(--text-muted); text-transform:uppercase;">Service</div>
                    <div style="font-weight: 500; color: var(--text-primary);">${apt.service_name}</div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 12px; color: var(--text-muted); text-transform:uppercase;">Stylist</div>
                    <div style="font-weight: 500; display: flex; align-items: center; gap: 6px;">
                        <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(apt.staff_name)}&background=random" style="width:18px; height:18px; border-radius:50%;"> ${apt.staff_name.split(' ')[0]}
                    </div>
                </div>
            </div>
        </div>`;
    });

    if (filteredData.length === 0) {
        gridHtml = `<div style="grid-column: 1 / -1; color: var(--text-secondary); padding: 60px; text-align: center; font-size: 15px; background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light);">No ${activeAptFilter} appointments found.</div>`;
    }

    const filtersHtml = `
    <div style="display: flex; gap: 8px; flex-wrap: wrap;">
        ${['all', 'upcoming', 'active', 'completed', 'cancelled'].map(filter => {
            const isActive = activeAptFilter === filter;
            const bg = isActive ? 'var(--accent-gold)' : 'var(--bg-glass)';
            const color = isActive ? '#111' : 'var(--text-secondary)';
            const border = isActive ? '1px solid var(--accent-gold)' : '1px solid var(--border-color)';
            return `<button onclick="setAptFilter('${filter}')" class="btn" style="padding: 6px 16px; font-size: 13px; background: ${bg}; color: ${color}; border: ${border}; text-transform: capitalize; transition: all 0.2s;">${filter}</button>`;
        }).join('')}
    </div>
    `;

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 28px; flex-wrap: wrap; gap: 16px;">
                <h3 style="margin-bottom: 0;">Appointments Calendar</h3>
                ${filtersHtml}
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 24px;">
                ${gridHtml}
            </div>
        </div>
    `;
}

window.setAptFilter = function(filter) {
    activeAptFilter = filter;
    renderAppointments();
};

async function renderClients() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading...</div>';
    const data = await fetchData('clients');
    if (!data) return;

    let rowsHtml = '';
    data.forEach(client => {
        rowsHtml += `
        <tr style="border-bottom: 1px solid var(--border-light); transition: background 0.2s;">
            <td style="padding: 16px 24px;">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(client.name)}&background=random" style="width:36px; height:36px; border-radius:50%;">
                    <div>
                        <div style="font-weight: 500; color: var(--text-primary);">${client.name}</div>
                    </div>
                </div>
            </td>
            <td style="padding: 16px 24px;">
                <div style="font-size: 14px;">${client.email || 'N/A'}</div>
                <div style="font-size: 13px; color: var(--text-muted);">${client.phone || 'N/A'}</div>
            </td>
            <td style="padding: 16px 24px; font-size: 14px;">${client.last_visit || 'Never'}</td>
            <td style="padding: 16px 24px; font-weight: 500; color:var(--accent-gold);">$${parseFloat(client.total_spent || 0).toFixed(2)}</td>
        </tr>`;
    });

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h3 style="margin-bottom: 0;">Clients Directory</h3>
            </div>
            <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); overflow: hidden;">
                <table style="width: 100%; border-collapse: collapse; text-align: left;">
                    <thead style="background: rgba(0,0,0,0.2); font-size: 13px; color: var(--text-muted); text-transform: uppercase;">
                        <tr>
                            <th style="padding: 16px 24px; font-weight: 600;">Client</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Contact</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Last Visit</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Total Spent</th>
                        </tr>
                    </thead>
                    <tbody>${rowsHtml}</tbody>
                </table>
            </div>
        </div>
    `;
}

async function renderServices() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading...</div>';
    const data = await fetchData('services');
    if (!data) return;

    const categories = {};
    data.forEach(s => {
        if (!categories[s.category]) categories[s.category] = [];
        categories[s.category].push(s);
    });

    let catHtml = '';
    for (const [catName, svcs] of Object.entries(categories)) {
        let svcsHtml = svcs.map(s => `
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-light); padding-bottom: 16px;">
                <div>
                    <div style="font-weight: 500;">${s.name}</div>
                    <div style="font-size: 13px; color: var(--text-muted);">${s.description} • ${s.duration_mins}m</div>
                </div>
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="font-weight: 600; font-size: 16px; color:var(--accent-gold);">$${parseFloat(s.price).toFixed(2)}</div>
                    <button onclick="openEditServiceModal(${s.id}, '${s.name.replace(/'/g, "\\'")}', '${s.description.replace(/'/g, "\\'")}', ${s.duration_mins}, ${s.price}, '${s.category}')" class="btn-icon" style="width:28px; height:28px; font-size:12px; background:rgba(229,165,93,0.1); border-color:transparent; color:var(--accent-gold);"><i class="ph ph-note-pencil"></i></button>
                </div>
            </div>
        `).join('');

        catHtml += `
        <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); padding: 24px;">
            <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 20px;">
                <div style="width: 40px; height: 40px; border-radius: var(--radius-md); background: rgba(229,165,93,0.1); display: flex; align-items: center; justify-content: center; color: var(--accent-gold); font-size: 20px;">
                    <i class="ph ph-sparkle"></i>
                </div>
                <h4 style="margin: 0; font-family: var(--font-body); font-weight: 600; font-size: 18px;">${catName}</h4>
            </div>
            <div style="display: flex; flex-direction: column; gap: 16px;">
                ${svcsHtml}
            </div>
        </div>`;
    }

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h3 style="margin-bottom: 0;">Services Menu</h3>
                <button class="btn btn-primary" id="btn-add-service"><i class="ph ph-plus"></i> Add Service</button>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 24px;">
                ${catHtml}
            </div>
        </div>
    `;

    // Add Service Modal binding
    const modal = document.getElementById('add-service-modal');
    document.getElementById('btn-add-service').addEventListener('click', () => modal.style.display = 'flex');
    document.getElementById('close-service-modal').addEventListener('click', () => modal.style.display = 'none');
    document.getElementById('cancel-service-modal').addEventListener('click', () => modal.style.display = 'none');
    
    document.getElementById('add-service-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            name: document.getElementById('s-name').value,
            description: document.getElementById('s-desc').value,
            duration_mins: parseInt(document.getElementById('s-duration').value),
            price: parseFloat(document.getElementById('s-price').value),
            category: document.getElementById('s-category').value
        };
        const res = await fetchData('services', 'POST', payload);
        if (res && res.success) {
            modal.style.display = 'none';
            document.getElementById('add-service-form').reset();
            renderServices();
        }
    };

    // Edit Service Modal binding
    const editModal = document.getElementById('edit-service-modal');
    document.getElementById('close-edit-service-modal').onclick = () => editModal.style.display = 'none';
    document.getElementById('cancel-edit-service-modal').onclick = () => editModal.style.display = 'none';
    
    document.getElementById('edit-service-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            id: parseInt(document.getElementById('edit-service-id').value),
            name: document.getElementById('edit-s-name').value,
            description: document.getElementById('edit-s-desc').value,
            duration_mins: parseInt(document.getElementById('edit-s-duration').value),
            price: parseFloat(document.getElementById('edit-s-price').value),
            category: document.getElementById('edit-s-category').value
        };
        const res = await fetchData('services_update', 'POST', payload);
        if (res && res.success) {
            editModal.style.display = 'none';
            document.getElementById('edit-service-form').reset();
            renderServices();
        }
    };

    window.openEditServiceModal = function(id, name, description, durationMins, price, category) {
        document.getElementById('edit-service-id').value = id;
        document.getElementById('edit-s-name').value = name;
        document.getElementById('edit-s-desc').value = description;
        document.getElementById('edit-s-duration').value = durationMins;
        document.getElementById('edit-s-price').value = price;
        document.getElementById('edit-s-category').value = category;
        editModal.style.display = 'flex';
    };
}

async function renderStaff() {
    if (currentUser.role === 'receptionist') {
        pageContainer.innerHTML = '<div class="fade-in" style="color:var(--danger);">Unauthorized view</div>';
        return;
    }
    
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading...</div>';
    const data = await fetchData('staff');
    if (!data) return;

    let gridHtml = '';
    data.forEach(st => {
        const specs = st.specializations ? st.specializations.split(',').map(s => `<span style="font-size: 12px; background: var(--bg-glass); padding: 4px 10px; border-radius: 20px; color: var(--text-secondary); margin-right:4px;">${s.trim()}</span>`).join('') : '';
        const statusText = st.status ? st.status.replace('_', ' ') : 'active';
        const statusDot = st.status === 'available' ? 'status-active' : (st.status === 'in_service' ? 'status-upcoming' : (st.status === 'off' ? 'status-cancelled' : 'status-active'));
        const commissionLabel = st.commission_rate ? `${st.commission_rate}%` : '0%';

        gridHtml += `
        <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); padding: 24px; text-align: center;">
            <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(st.name)}&background=random" style="width:80px; height:80px; border-radius:50%; margin-bottom: 16px; border: 3px solid var(--border-color);">
            <div style="font-size: 18px; font-weight: 600; margin-bottom: 4px;">${st.name}</div>
            <div style="color: var(--accent-gold); font-size: 14px; font-weight: 500; margin-bottom: 8px;">${st.role}</div>
            <div style="font-size: 13px; color: var(--text-muted); margin-bottom: 16px;">Commission: ${commissionLabel} (${st.commission_type})</div>
            <div style="display: flex; justify-content: center; flex-wrap: wrap; gap: 4px; margin-bottom: 20px;">
                ${specs}
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 16px; border-top: 1px solid var(--border-light);">
                <div style="display: flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 500; text-transform: capitalize;">
                    <span class="status-dot ${statusDot}"></span> ${statusText}
                </div>
                <button onclick="openEditStaffModal(${st.user_id}, '${st.name.replace(/'/g, "\\'")}', '${st.username.replace(/'/g, "\\'")}', ${st.commission_rate || 0}, '${st.commission_type || 'percentage'}', '${(st.specializations || '').replace(/'/g, "\\'")}', '${st.role}')" class="btn" style="padding: 6px 12px; font-size: 12px; background: rgba(229,165,93,0.15); border: 1px solid var(--accent-gold); color: var(--accent-gold);"><i class="ph ph-note-pencil"></i> Edit</button>
            </div>
        </div>`;
    });

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h3 style="margin-bottom: 0;">Staff Directory</h3>
                <button class="btn btn-primary" id="btn-add-staff"><i class="ph ph-plus"></i> Add Staff</button>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 24px;">
                ${gridHtml}
            </div>
        </div>
    `;

    // Bind Staff Modal
    const modal = document.getElementById('add-staff-modal');
    
    // Add Password fields to staff form if not exists
    let pwdField = document.getElementById('staff-pwd');
    if (!pwdField) {
        const specsField = document.getElementById('staff-specializations').parentNode;
        const pwdDiv = document.createElement('div');
        pwdDiv.style.marginBottom = '16px';
        pwdDiv.innerHTML = `
            <label style="display:block; margin-bottom:8px; font-size:14px; color:var(--text-secondary);">Portal Account Credentials</label>
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                <input type="text" id="staff-username" required placeholder="Username" style="width:100%; padding:10px 14px; background:rgba(0,0,0,0.2); border:1px solid var(--border-color); border-radius:var(--radius-md); color:white; font-family:inherit;">
                <input type="password" id="staff-pwd" required placeholder="Portal Password" style="width:100%; padding:10px 14px; background:rgba(0,0,0,0.2); border:1px solid var(--border-color); border-radius:var(--radius-md); color:white; font-family:inherit;">
            </div>
        `;
        specsField.parentNode.insertBefore(pwdDiv, specsField);
        
        const commDiv = document.createElement('div');
        commDiv.style.marginBottom = '16px';
        commDiv.innerHTML = `
            <label style="display:block; margin-bottom:8px; font-size:14px; color:var(--text-secondary);">Commission Configuration</label>
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                <input type="number" id="staff-comm-rate" required placeholder="Commission Rate" value="30.0" step="0.1" style="width:100%; padding:10px 14px; background:rgba(0,0,0,0.2); border:1px solid var(--border-color); border-radius:var(--radius-md); color:white; font-family:inherit;">
                <select id="staff-comm-type" required style="width:100%; padding:10px 14px; background:var(--bg-secondary); border:1px solid var(--border-color); border-radius:var(--radius-md); color:white; font-family:inherit;">
                    <option value="percentage">Percentage (%)</option>
                    <option value="fixed">Fixed ($)</option>
                </select>
            </div>
        `;
        specsField.parentNode.insertBefore(commDiv, specsField);
    }

    document.getElementById('btn-add-staff').onclick = () => modal.style.display = 'flex';
    document.getElementById('close-staff-modal').onclick = () => modal.style.display = 'none';
    document.getElementById('cancel-staff-modal').onclick = () => modal.style.display = 'none';
    
    document.getElementById('add-staff-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            name: document.getElementById('staff-name').value,
            role: 'stylist', // automatically registers as stylist
            username: document.getElementById('staff-username').value,
            password: document.getElementById('staff-pwd').value,
            commission_rate: parseFloat(document.getElementById('staff-comm-rate').value),
            commission_type: document.getElementById('staff-comm-type').value,
            specializations: document.getElementById('staff-specializations').value
        };
        const res = await fetchData('register', 'POST', payload);
        if (res && res.success) {
            modal.style.display = 'none';
            document.getElementById('add-staff-form').reset();
            renderStaff();
        }
    };

    // Bind Edit Staff Modal
    const editModal = document.getElementById('edit-staff-modal');
    document.getElementById('close-edit-staff-modal').onclick = () => editModal.style.display = 'none';
    document.getElementById('cancel-edit-staff-modal').onclick = () => editModal.style.display = 'none';
    
    document.getElementById('edit-staff-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            user_id: parseInt(document.getElementById('edit-staff-id').value),
            name: document.getElementById('edit-staff-name').value,
            username: document.getElementById('edit-staff-username').value,
            password: document.getElementById('edit-staff-pwd').value || null,
            commission_rate: parseFloat(document.getElementById('edit-staff-comm-rate').value || 0),
            commission_type: document.getElementById('edit-staff-comm-type').value,
            specializations: document.getElementById('edit-staff-specializations').value
        };
        const res = await fetchData('staff_update', 'POST', payload);
        if (res && res.success) {
            editModal.style.display = 'none';
            document.getElementById('edit-staff-form').reset();
            renderStaff();
        }
    };

    window.openEditStaffModal = function(userId, name, username, commRate, commType, specializations, role) {
        document.getElementById('edit-staff-id').value = userId;
        document.getElementById('edit-staff-name').value = name;
        document.getElementById('edit-staff-username').value = username;
        document.getElementById('edit-staff-pwd').value = '';

        const commSection = document.getElementById('edit-staff-comm-section');
        const specsSection = document.getElementById('edit-staff-specs-section');

        if (role === 'stylist') {
            commSection.style.display = 'block';
            specsSection.style.display = 'block';
            document.getElementById('edit-staff-comm-rate').value = commRate;
            document.getElementById('edit-staff-comm-type').value = commType;
            document.getElementById('edit-staff-specializations').value = specializations;
        } else {
            commSection.style.display = 'none';
            specsSection.style.display = 'none';
            document.getElementById('edit-staff-comm-rate').value = '0';
            document.getElementById('edit-staff-comm-type').value = 'percentage';
            document.getElementById('edit-staff-specializations').value = '';
        }

        editModal.style.display = 'flex';
    };
}

// 1. POS CHECKOUT SCREEN
async function renderCheckout() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading POS...</div>';
    
    const clients = await fetchData('clients');
    const services = await fetchData('services');
    const products = await fetchData('inventory');
    const staff = await fetchData('staff');
    
    if (!clients || !services || !products || !staff) return;
    
    // Build screen UI
    pageContainer.innerHTML = `
        <div class="fade-in" style="display:grid; grid-template-columns: 1fr 380px; gap:24px; align-items:start;">
            <!-- Left Side: POS selectors -->
            <div style="display:flex; flex-direction:column; gap:24px;">
                <!-- Services grid -->
                <div style="background:var(--bg-card); border:1px solid var(--border-light); padding:24px; border-radius:var(--radius-lg);">
                    <h4 style="margin-bottom:16px; display:flex; align-items:center; gap:8px;"><i class="ph ph-sparkle"></i> Add Service to Order</h4>
                    <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap:12px; max-height: 250px; overflow-y:auto; padding-right:6px;">
                        ${services.map(s => `
                            <div onclick="addCartItem('service', ${s.id}, '${s.name.replace(/'/g, "\\'")}', ${s.price})" 
                                 style="background:var(--bg-glass); border:1px solid var(--border-color); border-radius:var(--radius-md); padding:12px; cursor:pointer; text-align:center; transition:var(--transition-fast);"
                                 onmouseover="this.style.borderColor='var(--accent-gold)'"
                                 onmouseout="this.style.borderColor='var(--border-color)'">
                                <div style="font-weight:600; font-size:14px; margin-bottom:4px; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;">${s.name}</div>
                                <div style="color:var(--accent-gold); font-size:13px; font-weight:500;">$${parseFloat(s.price).toFixed(2)}</div>
                            </div>
                        `).join('')}
                    </div>
                </div>

                <!-- Products grid -->
                <div style="background:var(--bg-card); border:1px solid var(--border-light); padding:24px; border-radius:var(--radius-lg);">
                    <h4 style="margin-bottom:16px; display:flex; align-items:center; gap:8px;"><i class="ph ph-package"></i> Add Product to Order</h4>
                    <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap:12px; max-height: 250px; overflow-y:auto; padding-right:6px;">
                        ${products.filter(p => p.category === 'retail_sale').map(p => `
                            <div onclick="addCartItem('product', ${p.id}, '${p.name.replace(/'/g, "\\'")}', ${p.price})" 
                                 style="background:var(--bg-glass); border:1px solid var(--border-color); border-radius:var(--radius-md); padding:12px; cursor:pointer; text-align:center; transition:var(--transition-fast);"
                                 onmouseover="this.style.borderColor='var(--accent-gold)'"
                                 onmouseout="this.style.borderColor='var(--border-color)'">
                                <div style="font-weight:600; font-size:14px; margin-bottom:4px; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;">${p.name}</div>
                                <div style="color:var(--text-muted); font-size:12px; margin-bottom:4px;">Stock: ${p.stock_quantity}</div>
                                <div style="color:var(--accent-gold); font-size:13px; font-weight:500;">$${parseFloat(p.price).toFixed(2)}</div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            </div>

            <!-- Right Side: Order summary cart & checkout controls -->
            <div style="background:var(--bg-card); border:1px solid var(--border-light); padding:24px; border-radius:var(--radius-lg); display:flex; flex-direction:column; gap:20px;">
                <h4 style="margin:0; display:flex; align-items:center; gap:8px;"><i class="ph ph-shopping-cart"></i> Invoice Details</h4>
                
                <!-- Client selector -->
                <div>
                    <label style="display:block; font-size:12px; color:var(--text-muted); text-transform:uppercase; margin-bottom:6px;">Select Client</label>
                    <select id="pos-client" style="width:100%; padding:10px; background:var(--bg-secondary); border:1px solid var(--border-color); border-radius:var(--radius-md); color:white; font-family:inherit;">
                        <option value="">Walk-in Customer</option>
                        ${clients.map(c => `<option value="${c.id}">${c.name} (${c.phone})</option>`).join('')}
                    </select>
                </div>

                <div style="height:1px; background:var(--border-light);"></div>

                <!-- Cart List -->
                <div style="min-height:180px; max-height:280px; overflow-y:auto; display:flex; flex-direction:column; gap:12px; padding-right:4px;" id="pos-cart-list">
                    <div style="text-align:center; color:var(--text-muted); padding-top:60px; font-size:13px;">Cart is empty. Select items.</div>
                </div>

                <div style="height:1px; background:var(--border-light);"></div>

                <!-- Totals -->
                <div style="display:flex; justify-content:space-between; font-weight:600; font-size:18px;">
                    <span>Total Amount</span>
                    <span style="color:var(--accent-gold);" id="pos-total-amount">$0.00</span>
                </div>

                <!-- Payment Method -->
                <div>
                    <label style="display:block; font-size:12px; color:var(--text-muted); text-transform:uppercase; margin-bottom:6px;">Payment Method</label>
                    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                        <button class="btn" id="pay-cash-btn" onclick="setPaymentMethod('cash')" style="width:100%; border:1px solid var(--accent-gold); background:var(--accent-gold-glow); color:var(--accent-gold);">Cash</button>
                        <button class="btn" id="pay-digital-btn" onclick="setPaymentMethod('digital')" style="width:100%; border:1px solid var(--border-color); background:transparent;">Digital</button>
                    </div>
                </div>

                <button class="btn btn-primary" onclick="submitPOSCheckout()" style="width:100%; padding:14px; text-transform:uppercase; letter-spacing:1px; font-weight:600;" id="checkout-btn" disabled>Complete Checkout</button>
            </div>
        </div>
    `;

    // Initialize Cart
    posCart = [];
    selectedPaymentMethod = 'cash';
    selectedPOSClient = null;
    stylistsList = staff;
    updateCartUI();
}

let selectedPaymentMethod = 'cash';
let stylistsList = [];

window.setPaymentMethod = function(method) {
    selectedPaymentMethod = method;
    const cashBtn = document.getElementById('pay-cash-btn');
    const digitalBtn = document.getElementById('pay-digital-btn');
    if (method === 'cash') {
        cashBtn.style.border = '1px solid var(--accent-gold)';
        cashBtn.style.background = 'var(--accent-gold-glow)';
        cashBtn.style.color = 'var(--accent-gold)';
        digitalBtn.style.border = '1px solid var(--border-color)';
        digitalBtn.style.background = 'transparent';
        digitalBtn.style.color = 'var(--text-primary)';
    } else {
        digitalBtn.style.border = '1px solid var(--accent-gold)';
        digitalBtn.style.background = 'var(--accent-gold-glow)';
        digitalBtn.style.color = 'var(--accent-gold)';
        cashBtn.style.border = '1px solid var(--border-color)';
        cashBtn.style.background = 'transparent';
        cashBtn.style.color = 'var(--text-primary)';
    }
};

window.addCartItem = function(type, id, name, price) {
    const existing = posCart.find(item => item.item_type === type && item.item_id === id);
    if (existing) {
        existing.quantity++;
    } else {
        posCart.push({
            item_type: type,
            item_id: id,
            name: name,
            price: price,
            quantity: 1,
            stylist_id: stylistsList.length > 0 ? stylistsList[0].id : null
        });
    }
    updateCartUI();
};

window.removeCartItem = function(index) {
    posCart.splice(index, 1);
    updateCartUI();
};

window.changeCartStylist = function(index, stylistId) {
    posCart[index].stylist_id = parseInt(stylistId);
};

window.changeCartQty = function(index, qty) {
    posCart[index].quantity = parseInt(qty);
    if (posCart[index].quantity <= 0) {
        removeCartItem(index);
    } else {
        updateCartUI();
    }
};

function updateCartUI() {
    const list = document.getElementById('pos-cart-list');
    const totalEl = document.getElementById('pos-total-amount');
    const checkoutBtn = document.getElementById('checkout-btn');
    
    if (posCart.length === 0) {
        list.innerHTML = '<div style="text-align:center; color:var(--text-muted); padding-top:60px; font-size:13px;">Cart is empty. Select items.</div>';
        totalEl.textContent = '$0.00';
        checkoutBtn.disabled = true;
        return;
    }

    let total = 0.0;
    list.innerHTML = posCart.map((item, idx) => {
        total += parseFloat(item.price) * item.quantity;
        return `
            <div style="background:var(--bg-glass); border:1px solid var(--border-color); border-radius:var(--radius-md); padding:12px; display:flex; flex-direction:column; gap:8px; position:relative;">
                <button onclick="removeCartItem(${idx})" class="btn-icon" style="position:absolute; top:8px; right:8px; width:24px; height:24px; font-size:12px; background:rgba(248,113,113,0.1); border-color:transparent; color:var(--danger);"><i class="ph ph-trash"></i></button>
                <div style="font-weight:600; font-size:14px; max-width:85%;">${item.name} (${item.item_type})</div>
                
                <div style="display:flex; justify-content:space-between; align-items:center; font-size:13px;">
                    <div>$${parseFloat(item.price).toFixed(2)} ea</div>
                    <div style="display:flex; align-items:center; gap:8px;">
                        <button class="btn-icon" style="width:20px; height:20px; font-size:11px;" onclick="changeCartQty(${idx}, ${item.quantity - 1})">-</button>
                        <span style="font-weight:600;">${item.quantity}</span>
                        <button class="btn-icon" style="width:20px; height:20px; font-size:11px;" onclick="changeCartQty(${idx}, ${item.quantity + 1})">+</button>
                    </div>
                </div>

                <div>
                    <label style="font-size:11px; color:var(--text-muted); text-transform:uppercase;">Stylist</label>
                    <select onchange="changeCartStylist(${idx}, this.value)" style="width:100%; padding:4px 8px; background:var(--bg-secondary); border:1px solid var(--border-color); border-radius:var(--radius-sm); color:white; font-size:12px; font-family:inherit;">
                        ${stylistsList.map(st => `<option value="${st.id}" ${item.stylist_id === st.id ? 'selected' : ''}>${st.name}</option>`).join('')}
                    </select>
                </div>
            </div>
        `;
    }).join('');

    totalEl.textContent = `$${total.toFixed(2)}`;
    checkoutBtn.disabled = false;
}

window.submitPOSCheckout = async function() {
    const checkoutBtn = document.getElementById('checkout-btn');
    checkoutBtn.disabled = true;
    checkoutBtn.innerHTML = '<i class="ph ph-spinner ph-spin"></i> Processing...';
    
    const clientSelect = document.getElementById('pos-client');
    const clientId = clientSelect.value ? parseInt(clientSelect.value) : null;
    
    const payload = {
        client_id: clientId,
        payment_method: selectedPaymentMethod,
        items: posCart
    };
    
    const res = await fetchData('checkout', 'POST', payload);
    if (res && res.success) {
        alert('POS checkout completed successfully!');
        renderCheckout();
    } else {
        checkoutBtn.disabled = false;
        checkoutBtn.textContent = 'Complete Checkout';
    }
};

// 2. INVENTORY STOCK MANAGER
async function renderInventory() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading Inventory...</div>';
    
    const data = await fetchData('inventory');
    if (!data) return;

    let rowsHtml = '';
    data.forEach(item => {
        const isLow = item.stock_quantity <= item.min_stock_alert;
        const statusColor = isLow ? 'var(--danger)' : 'var(--success)';
        const statusText = isLow ? 'LOW STOCK ALERT' : 'IN STOCK';
        const priceLabel = item.price > 0 ? `$${parseFloat(item.price).toFixed(2)}` : 'N/A';

        rowsHtml += `
        <tr style="border-bottom: 1px solid var(--border-light); transition: background 0.2s;">
            <td style="padding: 16px 24px;">
                <div style="font-weight: 600; color: var(--text-primary);">${item.name}</div>
                <div style="font-size:12px; color:var(--text-muted);">${item.description || 'No description'}</div>
            </td>
            <td style="padding: 16px 24px; font-size: 14px; text-transform: capitalize;">${item.category.replace('_', ' ')}</td>
            <td style="padding: 16px 24px; font-weight: 500;">${priceLabel}</td>
            <td style="padding: 16px 24px; font-weight: 600; color: ${statusColor};">
                ${item.stock_quantity} <span style="font-size:12px; font-weight:500; color:var(--text-muted);">/ Alert: ${item.min_stock_alert}</span>
            </td>
            <td style="padding: 16px 24px; font-size: 12px; font-weight: 600; color: ${statusColor};">${statusText}</td>
            <td style="padding: 16px 24px; text-align: right;">
                <button onclick="adjustInventoryQty(${item.id}, '${item.name.replace(/'/g, "\\'")}')" class="btn" style="padding:6px 12px; font-size:12px; background:var(--bg-glass); border:1px solid var(--border-color); color:var(--text-primary);"><i class="ph ph-arrows-down-up"></i> Restock</button>
            </td>
        </tr>`;
    });

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h3 style="margin-bottom: 0;">Inventory Management</h3>
                <button class="btn btn-primary" id="btn-add-product"><i class="ph ph-plus"></i> Add Product</button>
            </div>
            
            <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); overflow: hidden;">
                <table style="width: 100%; border-collapse: collapse; text-align: left;">
                    <thead style="background: rgba(0,0,0,0.2); font-size: 13px; color: var(--text-muted); text-transform: uppercase;">
                        <tr>
                            <th style="padding: 16px 24px; font-weight: 600;">Product</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Category</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Retail Price</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Stock Level</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Status</th>
                            <th style="padding: 16px 24px; text-align: right;">Action</th>
                        </tr>
                    </thead>
                    <tbody>${rowsHtml}</tbody>
                </table>
            </div>
        </div>
    `;

    // Bind Product Modal
    const modal = document.getElementById('add-product-modal');
    document.getElementById('btn-add-product').onclick = () => modal.style.display = 'flex';
    document.getElementById('close-product-modal').onclick = () => modal.style.display = 'none';
    document.getElementById('cancel-product-modal').onclick = () => modal.style.display = 'none';
    
    document.getElementById('add-product-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            name: document.getElementById('p-name').value,
            description: document.getElementById('p-desc').value,
            price: parseFloat(document.getElementById('p-price').value),
            stock_quantity: parseFloat(document.getElementById('p-stock').value),
            category: document.getElementById('p-category').value,
            min_stock_alert: parseFloat(document.getElementById('p-min-alert').value)
        };
        const res = await fetchData('inventory', 'POST', payload);
        if (res && res.success) {
            modal.style.display = 'none';
            document.getElementById('add-product-form').reset();
            renderInventory();
        }
    };
}

window.adjustInventoryQty = async function(id, name) {
    const qtyStr = prompt(`Adjust stock quantity for ${name} (Enter positive number to add, negative to subtract):`);
    if (qtyStr === null) return;
    const qty = parseFloat(qtyStr);
    if (isNaN(qty)) {
        alert('Invalid quantity entered.');
        return;
    }
    
    const res = await fetchData('inventory_stock', 'POST', { id, quantity: qty });
    if (res && res.success) {
        renderInventory();
    }
};

// 3. EXPENSES SCREEN
async function renderExpenses() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading Expenses...</div>';
    
    const data = await fetchData('expenses');
    if (!data) return;

    let rowsHtml = '';
    data.forEach(item => {
        rowsHtml += `
        <tr style="border-bottom: 1px solid var(--border-light); transition: background 0.2s;">
            <td style="padding: 16px 24px; font-weight: 500;">${item.expense_date}</td>
            <td style="padding: 16px 24px; font-weight: 600;">${item.category}</td>
            <td style="padding: 16px 24px; color:var(--text-secondary);">${item.description || 'N/A'}</td>
            <td style="padding: 16px 24px; font-size:13px; color:var(--text-muted);">By ${item.logged_by_name}</td>
            <td style="padding: 16px 24px; font-weight: 600; color:var(--danger);">$${parseFloat(item.amount).toFixed(2)}</td>
        </tr>`;
    });

    pageContainer.innerHTML = `
        <div class="fade-in">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h3 style="margin-bottom: 0;">Salon Expenses Directory</h3>
                <button class="btn btn-primary" id="btn-add-expense"><i class="ph ph-plus"></i> Log Expense</button>
            </div>
            
            <div style="background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-light); overflow: hidden;">
                <table style="width: 100%; border-collapse: collapse; text-align: left;">
                    <thead style="background: rgba(0,0,0,0.2); font-size: 13px; color: var(--text-muted); text-transform: uppercase;">
                        <tr>
                            <th style="padding: 16px 24px; font-weight: 600;">Date</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Category</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Description</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Logged By</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Amount</th>
                        </tr>
                    </thead>
                    <tbody>${rowsHtml}</tbody>
                </table>
            </div>
        </div>
    `;

    // Bind Expense Modal
    const modal = document.getElementById('add-expense-modal');
    document.getElementById('exp-date').value = new Date().toISOString().split('T')[0];
    
    document.getElementById('btn-add-expense').onclick = () => modal.style.display = 'flex';
    document.getElementById('close-expense-modal').onclick = () => modal.style.display = 'none';
    document.getElementById('cancel-expense-modal').onclick = () => modal.style.display = 'none';
    
    document.getElementById('add-expense-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            category: document.getElementById('exp-category').value,
            amount: parseFloat(document.getElementById('exp-amount').value),
            description: document.getElementById('exp-desc').value,
            expense_date: document.getElementById('exp-date').value
        };
        const res = await fetchData('expenses', 'POST', payload);
        if (res && res.success) {
            modal.style.display = 'none';
            document.getElementById('add-expense-form').reset();
            renderExpenses();
        }
    };
}

// 4. DRAWER CLOSE & RECONCILIATION SCREEN
async function renderReconciliation() {
    pageContainer.innerHTML = '<div class="fade-in" style="color:var(--text-muted);"><i class="ph ph-spinner ph-spin"></i> Loading Drawer...</div>';
    
    const todayData = await fetchData('reconciliation_today');
    const historyData = await fetchData('reconciliation');
    
    if (!todayData || !historyData) return;

    let historyRowsHtml = '';
    historyData.forEach(item => {
        const isClosed = item.status === 'closed';
        const color = isClosed ? 'var(--text-muted)' : 'var(--success)';
        
        historyRowsHtml += `
        <tr style="border-bottom: 1px solid var(--border-light); transition: background 0.2s;">
            <td style="padding: 16px 24px; font-weight: 600;">${item.reconciliation_date}</td>
            <td style="padding: 16px 24px;">$${parseFloat(item.opening_cash).toFixed(2)}</td>
            <td style="padding: 16px 24px; color:var(--success); font-weight:500;">+$${parseFloat(item.total_cash_sales).toFixed(2)}</td>
            <td style="padding: 16px 24px; color:var(--info);">+$${parseFloat(item.digital_payments).toFixed(2)}</td>
            <td style="padding: 16px 24px; color:var(--danger); font-weight:500;">-$${parseFloat(item.logged_expenses).toFixed(2)}</td>
            <td style="padding: 16px 24px; font-weight: 600;">$${parseFloat(item.closing_balance).toFixed(2)}</td>
            <td style="padding: 16px 24px; font-weight: 600; color: ${color}; text-transform:uppercase;">${item.status}</td>
            <td style="padding: 16px 24px; font-size:13px; color:var(--text-muted);">${item.closed_by_name || 'N/A'}</td>
        </tr>`;
    });

    const isTodayClosed = todayData.status === 'closed';
    const statusLabel = isTodayClosed ? 'Closed Drawer' : 'Open Drawer';
    const statusDot = isTodayClosed ? 'status-completed' : 'status-active';

    pageContainer.innerHTML = `
        <div class="fade-in" style="display:grid; grid-template-columns: 1fr 360px; gap:24px; align-items:start;">
            <!-- Left Side: Reconciliation Log -->
            <div style="background: var(--bg-card); border: 1px solid var(--border-light); padding: 24px; border-radius: var(--radius-lg);">
                <h4 style="margin-bottom: 20px;">Reconciliation Ledger History</h4>
                <table style="width: 100%; border-collapse: collapse; text-align: left;">
                    <thead style="background: rgba(0,0,0,0.2); font-size: 12px; color: var(--text-muted); text-transform: uppercase;">
                        <tr>
                            <th style="padding: 16px 24px; font-weight: 600;">Date</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Opening</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Cash Sales</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Digital</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Expenses</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Closing</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Status</th>
                            <th style="padding: 16px 24px; font-weight: 600;">Closed By</th>
                        </tr>
                    </thead>
                    <tbody>${historyRowsHtml}</tbody>
                </table>
            </div>

            <!-- Right Side: Today Drawer Widget -->
            <div style="background:var(--bg-card); border:1px solid var(--border-light); padding:24px; border-radius:var(--radius-lg); display:flex; flex-direction:column; gap:20px;">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <h4 style="margin:0; display:flex; align-items:center; gap:8px;"><i class="ph ph-vault"></i> Today's Drawer</h4>
                    <span style="font-size:12px; font-weight:600; display:flex; align-items:center; gap:6px;">
                        <span class="status-dot ${statusDot}"></span> ${statusLabel}
                    </span>
                </div>
                
                <div style="display:flex; flex-direction:column; gap:12px; font-size:14px; color:var(--text-secondary);">
                    <div style="display:flex; justify-content:space-between;"><span>Opening Float (Cash)</span> <span style="color:var(--text-primary); font-weight:500;">$${parseFloat(todayData.opening_cash).toFixed(2)}</span></div>
                    <div style="display:flex; justify-content:space-between; color:var(--success);"><span>+ Cash Sales</span> <span style="font-weight:500;">+$${parseFloat(todayData.total_cash_sales).toFixed(2)}</span></div>
                    <div style="display:flex; justify-content:space-between; color:var(--danger);"><span>- Logged Expenses</span> <span style="font-weight:500;">-$${parseFloat(todayData.logged_expenses).toFixed(2)}</span></div>
                    <div style="display:flex; justify-content:space-between; color:var(--info);"><span>+ Digital Payments (POS)</span> <span style="font-weight:500;">+$${parseFloat(todayData.digital_payments).toFixed(2)}</span></div>
                    
                    <div style="height:1px; background:var(--border-light); margin:8px 0;"></div>
                    
                    <div style="display:flex; justify-content:space-between; font-size:16px; font-weight:600; color:var(--text-primary);">
                        <span>Expected Cash Balance</span> 
                        <span style="color:var(--accent-gold); font-family:var(--font-heading);">$${parseFloat(todayData.closing_balance).toFixed(2)}</span>
                    </div>
                </div>

                ${isTodayClosed ? `
                    <div style="text-align:center; padding:12px; background:rgba(255,255,255,0.05); color:var(--text-muted); border-radius:var(--radius-md); font-size:13px;">
                        Drawer closed by ${todayData.closed_by_name || 'Staff'} @ ${todayData.closed_at}
                    </div>
                ` : `
                    <button class="btn btn-primary" onclick="performDrawerReconciliation(${todayData.closing_balance})" style="width:100%; padding:14px; text-transform:uppercase; letter-spacing:1px; font-weight:600;">Perform Drawer Closure</button>
                `}
            </div>
        </div>
    `;
}

window.performDrawerReconciliation = async function(expectedBalance) {
    const countedStr = prompt(`Perform cash drawer closure.\nExpected Cash Balance: $${expectedBalance.toFixed(2)}\nEnter counted cash in drawer:`);
    if (countedStr === null) return;
    const countedCash = parseFloat(countedStr);
    
    if (isNaN(countedCash)) {
        alert('Invalid cash balance input.');
        return;
    }
    
    const diff = countedCash - expectedBalance;
    if (Math.abs(diff) > 0.01) {
        if (!confirm(`WARNING: Cash drawer discrepancy!\nExpected: $${expectedBalance.toFixed(2)}\nCounted: $${countedCash.toFixed(2)}\nDiscrepancy: $${diff.toFixed(2)}\n\nDo you want to proceed and close drawer with discrepancy?`)) {
            return;
        }
    }
    
    const payload = {
        date: new Date().toISOString().split('T')[0],
        closing_balance: countedCash
    };
    
    const res = await fetchData('reconciliation_close', 'POST', payload);
    if (res && res.success) {
        alert('Cash drawer closed and reconciled successfully!');
        renderReconciliation();
    }
};

// Router map
const router = {
    dashboard: renderDashboard,
    appointments: renderAppointments,
    clients: renderClients,
    services: renderServices,
    staff: renderStaff,
    checkout: renderCheckout,
    inventory: renderInventory,
    expenses: renderExpenses,
    reconciliation: renderReconciliation
};

function switchPage(pageKey) {
    if (!router[pageKey]) return;

    // Update active nav item
    navItems.forEach(item => {
        if (item.dataset.page === pageKey) {
            item.classList.add('active');
            pageTitle.textContent = item.querySelector('span').textContent;
        } else {
            item.classList.remove('active');
        }
    });

    // Render Dynamic Content
    router[pageKey]();
}

// Event Listeners for Nav
navItems.forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const targetPage = item.dataset.page;
        if (targetPage !== currentPage) {
            currentPage = targetPage;
            switchPage(currentPage);
        }
    });
});

themeToggle.addEventListener('click', () => {
    document.body.classList.toggle('light-theme');
    const icon = themeToggle.querySelector('i');
    if (document.body.classList.contains('light-theme')) {
        icon.classList.remove('ph-moon');
        icon.classList.add('ph-sun');
    } else {
        icon.classList.remove('ph-sun');
        icon.classList.add('ph-moon');
    }
});

// Bind Global New Appointment Modal
const btnNewApt = document.getElementById('btn-new-appointment');
const aptModal = document.getElementById('new-appointment-modal');

if (btnNewApt && aptModal) {
    btnNewApt.addEventListener('click', async () => {
        // Fetch services and staff dynamically to populate select options
        const services = await fetchData('services');
        const staff = await fetchData('staff');
        
        if (services && staff) {
            document.getElementById('apt-service-id').innerHTML = services.map(s => `<option value="${s.id}">${s.name} ($${parseFloat(s.price).toFixed(2)})</option>`).join('');
            document.getElementById('apt-staff-id').innerHTML = staff.map(st => `<option value="${st.id}">${st.name}</option>`).join('');
        }
        
        document.getElementById('apt-date').value = new Date().toISOString().split('T')[0];
        aptModal.style.display = 'flex';
    });

    document.getElementById('close-appointment-modal').onclick = () => aptModal.style.display = 'none';
    document.getElementById('cancel-appointment-modal').onclick = () => aptModal.style.display = 'none';
    
    document.getElementById('new-appointment-form').onsubmit = async (e) => {
        e.preventDefault();
        const payload = {
            client_name: document.getElementById('apt-client-name').value,
            client_email: document.getElementById('apt-client-email').value,
            client_phone: document.getElementById('apt-client-phone').value,
            service_id: parseInt(document.getElementById('apt-service-id').value),
            staff_id: parseInt(document.getElementById('apt-staff-id').value),
            date: document.getElementById('apt-date').value,
            time: document.getElementById('apt-time').value,
            client_type: document.getElementById('apt-client-type').value
        };
        
        const res = await fetchData('appointments', 'POST', payload);
        if (res && res.success) {
            aptModal.style.display = 'none';
            document.getElementById('new-appointment-form').reset();
            // Re-render dashboard or current screen
            if (currentPage === 'dashboard') renderDashboard();
            if (currentPage === 'appointments') renderAppointments();
        }
    };
}

// Init Application
checkSession();
