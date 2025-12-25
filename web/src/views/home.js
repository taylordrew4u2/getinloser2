import { fetchTrips, createTrip, joinTrip } from '../services/firebase.js';
import { router } from '../main.js';

export async function renderHome(container) {
  container.innerHTML = `
    <div class="header">
      <div class="container header-content">
        <a href="/" class="logo">✈️ Get In Loser</a>
        <div class="header-actions">
          <button class="btn btn-secondary" id="joinTripBtn">Join Trip</button>
          <button class="btn btn-primary" id="addTripBtn">+ New Trip</button>
        </div>
      </div>
    </div>
    
    <div class="container" style="padding-top: 24px; flex: 1;">
      <div id="tripsContainer">
        <div class="spinner"></div>
      </div>
    </div>
  `;
  
  // Load trips
  loadTrips();
  
  // Event listeners
  document.getElementById('addTripBtn').addEventListener('click', showAddTripModal);
  document.getElementById('joinTripBtn').addEventListener('click', showJoinTripModal);
}

async function loadTrips() {
  const container = document.getElementById('tripsContainer');
  
  try {
    const trips = await fetchTrips();
    
    if (trips.length === 0) {
      container.innerHTML = `
        <div class="empty-state">
          <h2>No trips yet</h2>
          <p>Create your first trip or join one using an invite code!</p>
        </div>
      `;
      return;
    }
    
    container.innerHTML = trips.map(trip => `
      <div class="card trip-card" data-trip-id="${trip.id}">
        <div class="trip-card-header">
          <div>
            <div class="trip-name">${escapeHtml(trip.name)}</div>
            <div class="trip-location">📍 ${escapeHtml(trip.location)}</div>
          </div>
          <div style="text-align: right; color: var(--text-secondary); font-size: 12px;">
            Code: <strong style="color: var(--accent-blue)">${trip.inviteCode}</strong>
          </div>
        </div>
        <div class="trip-dates">
          📅 ${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}
        </div>
      </div>
    `).join('');
    
    // Add click handlers
    document.querySelectorAll('.trip-card').forEach(card => {
      card.addEventListener('click', () => {
        const tripId = card.dataset.tripId;
        router.navigate(`/trip/${tripId}`);
      });
    });
  } catch (error) {
    container.innerHTML = `<div class="error-message">Error loading trips: ${error.message}</div>`;
  }
}

function showAddTripModal() {
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2 class="modal-title">Create New Trip</h2>
        <button class="btn btn-icon" id="closeModal">✕</button>
      </div>
      <div class="modal-body">
        <form id="addTripForm">
          <div class="form-group">
            <label class="form-label">Trip Name</label>
            <input type="text" class="form-input" id="tripName" required placeholder="e.g., Tokyo Adventure">
          </div>
          
          <div class="form-group">
            <label class="form-label">Location</label>
            <input type="text" class="form-input" id="tripLocation" required placeholder="e.g., Tokyo, Japan">
          </div>
          
          <div class="form-group">
            <label class="form-label">Start Date</label>
            <input type="date" class="form-input" id="startDate" required>
          </div>
          
          <div class="form-group">
            <label class="form-label">End Date</label>
            <input type="date" class="form-input" id="endDate" required>
          </div>
          
          <div id="formError" class="error-message hidden"></div>
        </form>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
        <button class="btn btn-primary" id="createBtn">Create Trip</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  const closeModal = () => modal.remove();
  
  document.getElementById('closeModal').addEventListener('click', closeModal);
  document.getElementById('cancelBtn').addEventListener('click', closeModal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal();
  });
  
  document.getElementById('createBtn').addEventListener('click', async () => {
    const form = document.getElementById('addTripForm');
    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }
    
    const name = document.getElementById('tripName').value;
    const location = document.getElementById('tripLocation').value;
    const startDate = new Date(document.getElementById('startDate').value);
    const endDate = new Date(document.getElementById('endDate').value);
    
    if (endDate < startDate) {
      document.getElementById('formError').textContent = 'End date must be after start date';
      document.getElementById('formError').classList.remove('hidden');
      return;
    }
    
    try {
      document.getElementById('createBtn').disabled = true;
      document.getElementById('createBtn').textContent = 'Creating...';
      
      await createTrip({ name, location, startDate, endDate });
      closeModal();
      loadTrips();
    } catch (error) {
      document.getElementById('formError').textContent = error.message;
      document.getElementById('formError').classList.remove('hidden');
      document.getElementById('createBtn').disabled = false;
      document.getElementById('createBtn').textContent = 'Create Trip';
    }
  });
}

function showJoinTripModal() {
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2 class="modal-title">Join Trip</h2>
        <button class="btn btn-icon" id="closeModal">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label class="form-label">Invite Code</label>
          <input type="text" class="form-input" id="inviteCode" required placeholder="Enter 6-character code" maxlength="6" style="text-transform: uppercase;">
        </div>
        <div id="formError" class="error-message hidden"></div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
        <button class="btn btn-primary" id="joinBtn">Join</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  const closeModal = () => modal.remove();
  const input = document.getElementById('inviteCode');
  
  input.addEventListener('input', (e) => {
    e.target.value = e.target.value.toUpperCase();
  });
  
  document.getElementById('closeModal').addEventListener('click', closeModal);
  document.getElementById('cancelBtn').addEventListener('click', closeModal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal();
  });
  
  document.getElementById('joinBtn').addEventListener('click', async () => {
    const code = input.value.trim();
    
    if (code.length !== 6) {
      document.getElementById('formError').textContent = 'Please enter a 6-character code';
      document.getElementById('formError').classList.remove('hidden');
      return;
    }
    
    try {
      document.getElementById('joinBtn').disabled = true;
      document.getElementById('joinBtn').textContent = 'Joining...';
      
      await joinTrip(code);
      closeModal();
      loadTrips();
    } catch (error) {
      document.getElementById('formError').textContent = error.message;
      document.getElementById('formError').classList.remove('hidden');
      document.getElementById('joinBtn').disabled = false;
      document.getElementById('joinBtn').textContent = 'Join';
    }
  });
}

function formatDate(date) {
  if (!date) return '';
  return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
